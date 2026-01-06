import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:heylo/core/services/zego_call_service.dart';
import 'package:heylo/core/supabase/supabase_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    as supabase
    hide AuthState;

import '../../../../core/session/session_store.dart';
import '../../../../features/chat/repositories/chat_repo.dart';
import '../../../../main.dart';
import '../../../calls/repositories/call_history_repo.dart';
import '../../../calls/view_models/notifiers/call_history_notifier.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repo.dart';
import '../../repositories/profile_repo.dart';
import '../state/auth_state.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  late final SupabaseDbAuthRepo _authRepo;
  late final SupabaseProfileRepo _profileRepo;

  @override
  AuthState build() {
    _authRepo = SupabaseDbAuthRepo(SupabaseDbAuthRepoClient.instance);
    _profileRepo = SupabaseProfileRepo(SupabaseDbAuthRepoClient.instance);
    return const AuthState();
  }

  // Add helper method to register device
  Future<void> _registerCurrentDevice(String uid) async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = await SessionStore.getDeviceId(); // USE STABLE UUID
      String deviceName = 'Unknown Device';
      String platform = 'unknown';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
        platform = 'android';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
        platform = 'ios';
      } else if (Platform.isMacOS) {
        platform = 'macos';
        deviceName = 'Mac Client';
      }

      final sessionId = await _authRepo.registerDevice(
        userId: uid,
        deviceId: deviceId,
        name: deviceName,
        platform: platform,
      );

      if (sessionId != null) {
        await SessionStore.saveSessionId(sessionId);
        _listenForRevocation(sessionId);
      }

      print('[AuthNotifier] Registered Session: $sessionId');
    } catch (e) {
      print('[AuthNotifier] Failed to register device: $e');
    }
  }

  supabase.RealtimeChannel? _revocationChannel;

  void _listenForRevocation(String sessionId) {
    _revocationChannel?.unsubscribe();

    print('[AuthNotifier] 🎯 WATCHING SESSION ID: $sessionId');

    _revocationChannel = supabase.Supabase.instance.client
        .channel('session_$sessionId')
        .onPostgresChanges(
          event: supabase.PostgresChangeEvent.delete,
          schema: 'public',
          table: 'user_devices',
          filter: supabase.PostgresChangeFilter(
            type: supabase.PostgresChangeFilterType.eq,
            column: 'id',
            value: sessionId,
          ),
          callback: (payload) {
            print('[AuthNotifier] 🔥 SESSION DELETED! Kicking out...');
            signOut(
              reason:
                  "You've been signed out because this device was removed from your active sessions remotely.",
            );
          },
        );

    _revocationChannel?.subscribe((status, error) {
      print('[AuthNotifier] 📡 Sub Status: $status');
    });
  }

  /// Send OTP (DB only). Returns OTP for dev/testing.
  Future<String?> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, otpError: null);
    try {
      final otp = await _authRepo.sendOtp(phone: phone);
      state = state.copyWith(
        isLoading: false,
        codeSent: true,
        phone: phone,
        lastOtp: otp,
      );
      return otp;
    } catch (e) {
      state = state.copyWith(isLoading: false, otpError: e.toString());
      return null;
    }
  }

  /// Verify OTP using DB and create/get user
  Future<bool> verifyOtp(
    String otp, {
    Function(bool newUser)? onSuccess,
    Function(String error)? onFailure,
  }) async {
    final phone = state.phone;
    if (phone == null) {
      onFailure?.call('No phone in state');
      return false;
    }

    state = state.copyWith(isLoading: true, otpError: null);
    try {
      final ok = await _authRepo.verifyOtp(phone: phone, otp: otp);

      if (!ok) {
        state = state.copyWith(isLoading: false);
        onFailure?.call('Invalid or expired code');
        return false;
      }

      final uid = await _authRepo.createOrGetUser(phone: phone);
      final profile = await _profileRepo.fetchUser(uid);

      state = state.copyWith(
        isLoading: false,
        isSignedIn: true,
        userId: uid,
        phone: phone,
        userName: profile?.name,
        userEmail: profile?.email,
        avatarUrl: profile?.avatarUrl,
        isProfileComplete: profile?.name != null && profile!.name!.isNotEmpty,
        privacyLastSeen: profile?.privacyLastSeen ?? 'everyone',
        privacyProfilePhoto: profile?.privacyProfilePhoto ?? 'everyone',
        privacyAbout: profile?.privacyAbout ?? 'everyone',
        privacyReadReceipts: profile?.privacyReadReceipts ?? 'everyone',
      );
      await SessionStore.saveUid(uid);
      await _registerCurrentDevice(uid);

      // Zego Login with call history tracking
      try {
        final appID = int.parse(dotenv.env['ZEGO_APP_ID']!);
        final appSign = dotenv.env['ZEGO_APP_SIGN']!;

        await ZegoCallService.instance.init(
          appID: appID,
          appSign: appSign,
          userID: uid,
          userName: profile?.name ?? 'User',
          navigatorKey: navigatorKey,
          onLogCall: (record) async {
            try {
              final notifier = ref.read(callHistoryProvider(uid).notifier);
              return await notifier.logCall(record);
            } catch (e) {
              print('[AuthNotifier] Error logging call: $e');
              return null;
            }
          },
          onUpdateCall: (id, {endedAt, durationSeconds, status}) async {
            try {
              final notifier = ref.read(callHistoryProvider(uid).notifier);
              await notifier.updateCallRecord(
                id,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                status: status,
              );

              // ALSO: Log this call as a chat message so it appears in Chat Room
              // IMPORTANT: Only the CALLER should log this to avoid duplicate messages
              // and because receivers might not have Permission to log on behalf of caller.
              final repo = CallHistoryRepo(supabase.Supabase.instance.client);
              final latest = await repo.getRecord(id);
              if (latest == null) return;

              if (latest.callerId != uid) {
                print('[AuthNotifier] Skipping chat log (not the caller)');
                return;
              }

              final chatRepo = ChatRepo(supabase.Supabase.instance.client);
              await chatRepo.sendCallMessage(
                senderId: latest.callerId,
                peerId: latest.receiverId,
                isVideo: latest.callType == 'video',
                durationSeconds: durationSeconds ?? 0,
                status: latest.status,
              );
            } catch (e) {
              print(
                '[AuthNotifier] Error updating call and logging to chat: $e',
              );
            }
          },
        );

        print('[AuthNotifier] Zego Call Init successful');
      } catch (e) {
        print('[AuthNotifier] Zego Call Init failed: $e');
      }

      onSuccess?.call(profile?.name == null);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      onFailure?.call(e.toString());
      return false;
    }
  }

  // ... (saveProfile remains unchanged)

  /// Save / update profile (DB + Storage)
  Future<bool> saveProfile({
    required String name,
    String? email,
    File? avatarFile,
  }) async {
    final uid = state.userId;
    final phone = state.phone ?? uid;

    if (uid == null) {
      state = state.copyWith(otpError: 'No authenticated user');
      return false;
    }

    state = state.copyWith(isLoading: true, otpError: null);
    try {
      String? avatarUrl = state.avatarUrl;

      if (avatarFile != null) {
        avatarUrl = await _profileRepo.uploadAvatar(uid: uid, file: avatarFile);
      }

      final now = DateTime.now();

      final user = UserModel(
        uid: uid,
        phone: phone ?? '',
        name: name,
        email: email,
        avatarUrl: avatarUrl,
        createdAt: now,
        lastSeen: now,
        privacyLastSeen: state.privacyLastSeen,
        privacyProfilePhoto: state.privacyProfilePhoto,
        privacyAbout: state.privacyAbout,
        privacyReadReceipts: state.privacyReadReceipts,
      );

      await _profileRepo.saveUser(user);

      state = state.copyWith(
        isLoading: false,
        isProfileComplete: true,
        userName: name,
        userEmail: email,
        avatarUrl: avatarUrl,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, otpError: e.toString());
      return false;
    }
  }

  Future<bool> restore(String uid) async {
    print('[AuthNotifier] Restoring user $uid...');
    final user = await _profileRepo.fetchUser(uid);
    if (user == null) {
      print('[AuthNotifier] User not found during restore.');
      return false;
    }

    state = state.copyWith(
      isSignedIn: true,
      userId: uid,
      phone: user.phone,
      userName: user.name,
      userEmail: user.email,
      avatarUrl: user.avatarUrl,
      isProfileComplete: user.name?.isNotEmpty ?? false,
      privacyLastSeen: user.privacyLastSeen,
      privacyProfilePhoto: user.privacyProfilePhoto,
      privacyAbout: user.privacyAbout,
      privacyReadReceipts: user.privacyReadReceipts,
    );

    await _registerCurrentDevice(uid);

    // Zego Login (Restore) with call history tracking
    try {
      print('[AuthNotifier] Attempting Zego login...');

      final appID = int.parse(dotenv.env['ZEGO_APP_ID']!);
      final appSign = dotenv.env['ZEGO_APP_SIGN']!;

      await ZegoCallService.instance.init(
        appID: appID,
        appSign: appSign,
        userID: uid,
        userName: user.name ?? 'User',
        navigatorKey: navigatorKey,
        onLogCall: (record) async {
          try {
            final notifier = ref.read(callHistoryProvider(uid).notifier);
            return await notifier.logCall(record);
          } catch (e) {
            print('[AuthNotifier] Error logging call: $e');
            return null;
          }
        },
        onUpdateCall: (id, {endedAt, durationSeconds, status}) async {
          try {
            final notifier = ref.read(callHistoryProvider(uid).notifier);
            await notifier.updateCallRecord(
              id,
              endedAt: endedAt,
              durationSeconds: durationSeconds,
              status: status,
            );

            // ALSO: Log this call as a chat message so it appears in Chat Room
            // IMPORTANT: Only the CALLER should log this to avoid duplicate messages
            // and because receivers might not have Permission to log on behalf of caller.
            final repo = CallHistoryRepo(supabase.Supabase.instance.client);
            final latest = await repo.getRecord(id);
            if (latest == null) return;

            if (latest.callerId != uid) {
              print('[AuthNotifier] Skipping chat log (not the caller)');
              return;
            }

            final chatRepo = ChatRepo(supabase.Supabase.instance.client);
            await chatRepo.sendCallMessage(
              senderId: latest.callerId,
              peerId: latest.receiverId,
              isVideo: latest.callType == 'video',
              durationSeconds: durationSeconds ?? 0,
              status: status ?? latest.status,
            );
          } catch (e) {
            print('[AuthNotifier] Error updating call and logging to chat: $e');
          }
        },
      );

      print('[AuthNotifier] Zego login successful.');
    } catch (e) {
      print('[AuthNotifier] Zego login failed: $e');
    }

    return true;
  }

  /// Clear in-memory session and persistent storage
  Future<void> signOut({String? reason}) async {
    print('[AuthNotifier] Signing out...');
    _revocationChannel?.unsubscribe();
    ZegoCallService.instance.uninit();
    await SessionStore.clear();
    state = AuthState(logoutReason: reason);
  }

  void clearError() {
    state = state.copyWith(otpError: null);
  }

  void clearLogoutReason() {
    state = state.copyWith(logoutReason: null);
  }

  Future<void> updateLastSeen() async {
    final uid = state.userId;
    if (uid != null) {
      try {
        await _profileRepo.updateLastSeen(uid);
      } catch (e) {
        print('[AuthNotifier] Failed to update last seen: $e');
      }
    }
  }

  Future<void> updatePrivacy(String key, String value) async {
    final uid = state.userId;
    if (uid == null) return;

    // Optimistic update
    // We can't easily update the full UserModel inside AuthState without fetching it again
    // or manually patching it. AuthState has flat fields for userName etc but not the full privacy config.
    // Wait, AuthState DOES NOT have privacy fields yet.
    // I should probably add them to AuthState if the UI needs to react immediately,
    // or just rely on re-fetching or the fact that these are settings.
    // However, PrivacyScreen reads from... wait. PrivacyScreen needs to read these values.
    // Currently AuthState does NOT have privacy fields.
    // Plan update: I need to add privacy fields to AuthState as well to reflect them in UI.

    try {
      await _profileRepo.updatePrivacySettings(uid, key, value);

      // Update local state
      if (key == 'privacy_last_seen') {
        state = state.copyWith(privacyLastSeen: value);
      } else if (key == 'privacy_profile_photo') {
        state = state.copyWith(privacyProfilePhoto: value);
      } else if (key == 'privacy_about') {
        state = state.copyWith(privacyAbout: value);
      } else if (key == 'privacy_read_receipts') {
        state = state.copyWith(privacyReadReceipts: value);
      }
    } catch (e) {
      print('[AuthNotifier] Failed to update privacy: $e');
      rethrow;
    }
  }
}
