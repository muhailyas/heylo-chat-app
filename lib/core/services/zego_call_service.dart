import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import '../../features/calls/models/call_record.dart';

class ZegoCallService {
  ZegoCallService._();
  static final ZegoCallService instance = ZegoCallService._();

  bool _isInit = false;
  ZegoUIKitSignalingPlugin? _signalingPlugin;

  // Track active call metadata
  String? _activeCallId;
  DateTime? _callStartTime;
  String? _currentUserId;
  String? _currentCallType;

  // Track logging state to prevent race conditions
  Future<void>? _loggingFuture;

  // Callback for logging calls
  Future<String?> Function(CallRecord)? _onLogCall;
  Future<void> Function(
    String id, {
    DateTime? endedAt,
    int? durationSeconds,
    String? status,
  })?
  _onUpdateCall;

  Future<void> init({
    required int appID,
    required String appSign,
    required String userID,
    required String userName,
    required GlobalKey<NavigatorState> navigatorKey,
    Future<String?> Function(CallRecord)? onLogCall,
    Future<void> Function(
      String id, {
      DateTime? endedAt,
      int? durationSeconds,
      String? status,
    })?
    onUpdateCall,
  }) async {
    if (_isInit && _currentUserId == userID) {
      debugPrint('[ZegoCallService] Already initialized for user $userID');
      return;
    }

    debugPrint('[ZegoCallService] Initializing for user: $userID ($userName)');
    _currentUserId = userID;
    _onLogCall = onLogCall;
    _onUpdateCall = onUpdateCall;

    _signalingPlugin ??= ZegoUIKitSignalingPlugin();

    ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);

    // Request necessary permissions for calling
    Future.microtask(() async {
      await [
        Permission.camera,
        Permission.microphone,
        Permission.notification,
        if (Platform.isAndroid) Permission.systemAlertWindow,
      ].request();
    });

    try {
      await ZegoUIKitPrebuiltCallInvitationService().init(
        appID: appID,
        appSign: appSign,
        userID: userID,
        userName: userName,
        plugins: [_signalingPlugin!],
        notificationConfig: ZegoCallInvitationNotificationConfig(
          androidNotificationConfig: ZegoCallAndroidNotificationConfig(
            showOnLockedScreen: true,
            showOnFullScreen: true,
            callChannel: ZegoCallAndroidNotificationChannelConfig(
              channelID: "ZegoData",
              channelName: "Call Notifications",
              sound: "notification",
              vibrate: true,
            ),
            messageChannel: ZegoCallAndroidNotificationChannelConfig(
              channelID: "ZegoMessage",
              channelName: "Message Notifications",
              sound: "notification",
              vibrate: true,
            ),
          ),
          iOSNotificationConfig: ZegoCallIOSNotificationConfig(
            systemCallingIconName: 'CallKitIcon',
          ),
        ),
        requireConfig: (ZegoCallInvitationData data) {
          _currentCallType = data.type == ZegoCallInvitationType.videoCall
              ? 'video'
              : 'voice';

          final config = (data.invitees.length > 1)
              ? ZegoCallInvitationType.videoCall == data.type
                    ? ZegoUIKitPrebuiltCallConfig.groupVideoCall()
                    : ZegoUIKitPrebuiltCallConfig.groupVoiceCall()
              : ZegoCallInvitationType.videoCall == data.type
              ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
              : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

          // Customizations
          config.topMenuBar.isVisible = true;
          config.topMenuBar.buttons = [
            ZegoCallMenuBarButtonName.hangUpButton,
            ZegoCallMenuBarButtonName.switchCameraButton,
            ZegoCallMenuBarButtonName.toggleMicrophoneButton,
            if (data.type == ZegoCallInvitationType.videoCall)
              ZegoCallMenuBarButtonName.toggleCameraButton,
          ];

          // Mark start time when answered (this callback effectively means call started)
          _callStartTime = DateTime.now();

          return config;
        },
        invitationEvents: ZegoUIKitPrebuiltCallInvitationEvents(
          onIncomingCallReceived:
              (
                String callID,
                ZegoCallUser inviter,
                ZegoCallInvitationType type,
                List<ZegoCallUser> invitees,
                String data,
              ) async {
                debugPrint('[ZegoCallService] Incoming call received: $callID');
                _currentCallType = type == ZegoCallInvitationType.videoCall
                    ? 'video'
                    : 'voice';
                _loggingFuture =
                    _logCall(
                      callerId: inviter.id,
                      receiverId: _currentUserId ?? userID,
                      callType: _currentCallType!,
                      status: 'missed', // Default until accepted/rej
                      zegoCallId: callID,
                    ).catchError(
                      (e) => debugPrint('[ZegoCallService] Log error: $e'),
                    );
              },
          onIncomingCallDeclineButtonPressed: () async {
            debugPrint('[ZegoCallService] Incoming call declined locally');
            // Wait for any pending log
            if (_loggingFuture != null) await _loggingFuture;

            if (_activeCallId != null && _onUpdateCall != null) {
              _onUpdateCall!(
                _activeCallId!,
                endedAt: DateTime.now(),
                durationSeconds: 0,
                status: 'rejected',
              ).catchError(
                (e) => debugPrint('[ZegoCallService] Update error: $e'),
              );
            }
            _resetCallState();
          },
          onIncomingCallCanceled:
              (String callID, ZegoCallUser inviter, String data) async {
                debugPrint(
                  '[ZegoCallService] Incoming call cancelled by caller',
                );
                // Wait for any pending log
                if (_loggingFuture != null) await _loggingFuture;

                if (_activeCallId != null && _onUpdateCall != null) {
                  _onUpdateCall!(
                    _activeCallId!,
                    endedAt: DateTime.now(),
                    durationSeconds: 0,
                    status: 'cancelled',
                  ).catchError(
                    (e) => debugPrint('[ZegoCallService] Update error: $e'),
                  );
                }
                _resetCallState();
              },
          onIncomingCallTimeout: (String callID, ZegoCallUser inviter) async {
            debugPrint('[ZegoCallService] Incoming call timeout');
            // Wait for any pending log
            if (_loggingFuture != null) await _loggingFuture;

            if (_activeCallId != null && _onUpdateCall != null) {
              await _onUpdateCall!(
                _activeCallId!,
                endedAt: DateTime.now(),
                durationSeconds: 0,
                status: 'missed',
              );
            }
            _resetCallState();
          },
          onOutgoingCallSent:
              (
                String callID,
                ZegoCallUser inviter,
                ZegoCallInvitationType type,
                List<ZegoCallUser> invitees,
                String data,
              ) async {
                debugPrint('[ZegoCallService] Outgoing call sent: $callID');
                _currentCallType = type == ZegoCallInvitationType.videoCall
                    ? 'video'
                    : 'voice';

                _loggingFuture =
                    _logCall(
                      callerId: _currentUserId ?? userID,
                      receiverId: invitees.isNotEmpty ? invitees.first.id : '',
                      callType: _currentCallType!,
                      status: 'missed',
                      zegoCallId: callID,
                    ).catchError(
                      (e) => debugPrint('[ZegoCallService] Log error: $e'),
                    );
              },
          onOutgoingCallCancelButtonPressed: () async {
            debugPrint(
              '[ZegoCallService] Outgoing call cancelled by local user',
            );
            if (_loggingFuture != null) await _loggingFuture;

            if (_activeCallId != null && _onUpdateCall != null) {
              _onUpdateCall!(
                _activeCallId!,
                endedAt: DateTime.now(),
                durationSeconds: 0,
                status: 'cancelled',
              ).catchError(
                (e) => debugPrint('[ZegoCallService] Update error: $e'),
              );
            }
            _resetCallState();
          },
          onOutgoingCallDeclined:
              (String callID, ZegoCallUser invitee, String data) async {
                debugPrint(
                  '[ZegoCallService] Outgoing call declined by remote',
                );

                if (_loggingFuture != null) await _loggingFuture;

                if (_activeCallId != null && _onUpdateCall != null) {
                  _onUpdateCall!(
                    _activeCallId!,
                    endedAt: DateTime.now(),
                    durationSeconds: 0,
                    status: 'rejected',
                  ).catchError(
                    (e) => debugPrint('[ZegoCallService] Update error: $e'),
                  );
                }
                _resetCallState();
              },
          onOutgoingCallTimeout:
              (
                String callID,
                List<ZegoCallUser> invitees,
                bool isTimeout,
              ) async {
                debugPrint('[ZegoCallService] Outgoing call timeout');

                if (_loggingFuture != null) await _loggingFuture;

                if (_activeCallId != null && _onUpdateCall != null) {
                  _onUpdateCall!(
                    _activeCallId!,
                    endedAt: DateTime.now(),
                    durationSeconds: 0,
                    status: 'missed',
                  ).catchError(
                    (e) => debugPrint('[ZegoCallService] Update error: $e'),
                  );
                }
                _resetCallState();
              },
          onOutgoingCallAccepted: (String callID, ZegoCallUser invitee) async {
            debugPrint('[ZegoCallService] Outgoing call accepted');
            // Do NOT re-log. Just mark pending future as done if strictly needed,
            // or update start time.
            if (_loggingFuture != null) await _loggingFuture;

            _callStartTime = DateTime.now();

            // Optionally update status to 'answered' if you have such a status,
            // otherwise we wait for onCallEnd to mark as 'completed'.
          },
        ),
        events: ZegoUIKitPrebuiltCallEvents(
          onCallEnd: (event, defaultAction) async {
            debugPrint('[ZegoCallService] Call ended: ${event.reason}');

            // Calculate duration
            final duration = _callStartTime != null
                ? DateTime.now().difference(_callStartTime!)
                : Duration.zero;

            // Determine final status
            // Only overwrite status if it's currently 'missed' (default from creation)
            // or if we have a specific reason to set 'completed'.
            // If it was already 'cancelled' or 'rejected' via invitation events,
            // _resetCallState likely clears _activeCallId, but if we are here,
            // the call screen was probably active.

            String finalStatus = 'completed';

            if (event.reason == ZegoCallEndReason.localHangUp ||
                event.reason == ZegoCallEndReason.remoteHangUp) {
              // If valid duration, it's completed. If 0 duration, maybe missed/cancelled?
              // But usually 'completed' is fine for accepted calls.
              finalStatus = duration.inSeconds > 0 ? 'completed' : 'missed';
            } else if (event.reason == ZegoCallEndReason.kickOut) {
              finalStatus = 'cancelled';
            } else {
              finalStatus = 'missed';
            }

            // Update the call record
            if (_loggingFuture != null) await _loggingFuture;

            if (_activeCallId != null && _onUpdateCall != null) {
              try {
                await _onUpdateCall!(
                  _activeCallId!,
                  endedAt: DateTime.now(),
                  durationSeconds: duration.inSeconds,
                  status: finalStatus,
                );
              } catch (e) {
                debugPrint('[ZegoCallService] Error updating call record: $e');
              }
            }

            _resetCallState();
            defaultAction.call();
          },
        ),
      );

      // Call this after init for better plugin synchronization
      ZegoUIKitPrebuiltCallInvitationService().useSystemCallingUI([
        _signalingPlugin!,
      ]);

      _isInit = true;
      debugPrint(
        '[ZegoCallService] Initialization complete and signaling connected',
      );
    } catch (e) {
      debugPrint('[ZegoCallService] Initialization failed: $e');
      _isInit = false;
      _currentUserId = null;
      rethrow;
    }

    // Retrieve and register FCM token for offline notifications
    _registerPushToken();
  }

  Future<void> _registerPushToken() async {
    try {
      final notificationSettings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      if (notificationSettings.authorizationStatus ==
          AuthorizationStatus.authorized) {
        String? token;
        if (Platform.isAndroid) {
          token = await FirebaseMessaging.instance.getToken();
        } else if (Platform.isIOS) {
          token = await FirebaseMessaging.instance.getAPNSToken();
        }

        if (token != null) {
          debugPrint('[ZegoCallService] Push Token: $token');
        }
      }
    } catch (e) {
      debugPrint('[ZegoCallService] Error getting push token: $e');
    }
  }

  /// Log a call (incoming or outgoing)
  Future<void> _logCall({
    required String callerId,
    required String receiverId,
    required String callType,
    required String status,
    String? zegoCallId,
  }) async {
    if (_onLogCall == null) return;

    try {
      final record = CallRecord(
        callerId: callerId,
        receiverId: receiverId,
        callType: callType,
        status: status,
        startedAt: DateTime.now(),
        zegoCallId: zegoCallId,
      );

      _activeCallId = await _onLogCall!(record);
      // _callStartTime is NOT set here; it's set when answered.
      // But we can track creation time if needed.

      print(
        '[ZegoCallService] Call logged locally with DB ID: $_activeCallId, Zego ID: $zegoCallId',
      );
    } catch (e) {
      print('[ZegoCallService] Error logging call: $e');
    }
  }

  /// Reset call state
  void _resetCallState() {
    _callStartTime = null;
    _activeCallId = null;
    _currentCallType = null;
    _loggingFuture = null;
  }

  void uninit() {
    if (!_isInit) return;
    ZegoUIKitPrebuiltCallInvitationService().uninit();
    _resetCallState();
    _currentUserId = null;
    _isInit = false;
  }
}
