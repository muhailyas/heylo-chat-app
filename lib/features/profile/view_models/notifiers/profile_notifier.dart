import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heylo/core/session/session_store.dart';
import 'package:heylo/core/supabase/supabase_client.dart';
import 'package:heylo/features/auth/models/user_model.dart';
import 'package:heylo/features/auth/repositories/profile_repo.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_notifier.g.dart';

@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  SupabaseProfileRepo get _repo =>
      SupabaseProfileRepo(SupabaseDbAuthRepoClient.instance);

  @override
  Future<UserModel?> build() async {
    return _loadProfile();
  }

  Future<UserModel?> _loadProfile() async {
    try {
      final uid = await SessionStore.readUid();
      if (uid == null) return null;
      return await _repo.fetchUser(uid);
    } catch (e) {
      print('[ProfileNotifier] Error loading profile: $e');
      return null;
    }
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? avatarUrl,
  }) async {
    final current = state.value;
    if (current == null) return;

    state = const AsyncValue.loading();

    try {
      final updated = UserModel(
        uid: current.uid,
        phone: current.phone,
        name: name ?? current.name,
        email: email ?? current.email,
        avatarUrl: avatarUrl ?? current.avatarUrl,
        createdAt: current.createdAt,
        lastSeen: DateTime.now(),
      );

      await _repo.saveUser(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      print('[ProfileNotifier] Error updating profile: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<String> uploadAvatar(String filePath) async {
    final current = state.value;
    if (current == null) throw Exception('No user logged in');

    try {
      final url = await _repo.uploadAvatar(
        uid: current.uid,
        file: File(filePath),
      );
      return url;
    } catch (e) {
      print('[ProfileNotifier] Error uploading avatar: $e');
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final profile = await _loadProfile();
    state = AsyncValue.data(profile);
  }
}

final profileByUidProvider = FutureProvider.family<UserModel?, String>((
  ref,
  uid,
) async {
  final repo = SupabaseProfileRepo(SupabaseDbAuthRepoClient.instance);
  return await repo.fetchUser(uid);
});
