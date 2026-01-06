// // Profile repository: fetch/save user, upload avatar
// // File: lib/features/auth/repositories/profile_repo.dart

// import 'dart:io';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';

// import '../../../core/firebase/firebase_service.dart';
// import '../models/user_model.dart';

// class ProfileRepo {
//   ProfileRepo({FirebaseFirestore? firestore, FirebaseStorage? storage})
//     : _db = firestore ?? FirebaseService.instance.firestore,
//       _storage = storage ?? FirebaseService.instance.storage;

//   final FirebaseFirestore _db;
//   final FirebaseStorage _storage;

//   Future<UserModel?> fetchUser(String uid) async {
//     final doc = await _db.collection('users').doc(uid).get();
//     if (!doc.exists) return null;
//     return UserModel.fromMap(doc.data()!..['uid'] = doc.id);
//   }

//   Future<void> saveUser(UserModel user) async {
//     final map = user.toMap();
//     await _db
//         .collection('users')
//         .doc(user.uid)
//         .set(map, SetOptions(merge: true));
//   }

//   /// Upload avatar file to storage and return public download URL.
//   Future<String> uploadAvatar({required String uid, required File file}) async {
//     final ref = _storage
//         .ref()
//         .child('avatars')
//         .child(uid)
//         .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
//     final uploadTask = await ref.putFile(file);
//     final url = await uploadTask.ref.getDownloadURL();
//     return url;
//   }
// }
// Supabase profile repository (DB + Storage, NO auth dependency)
// File: lib/features/auth/repositories/supabase_profile_repo.dart

import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';

class SupabaseProfileRepo {
  SupabaseProfileRepo(this._client);

  final SupabaseClient _client;

  static const String _usersTable = 'users';
  static const String _bucket = 'avatars';

  Future<UserModel?> fetchUser(String uid) async {
    final row = await _client
        .from(_usersTable)
        .select()
        .eq('uid', uid)
        .maybeSingle();

    if (row == null) return null;
    return UserModel.fromMap(row);
  }

  Future<List<UserModel>> fetchUsers(List<String> uids) async {
    if (uids.isEmpty) return [];

    // Batch fetch (chunking if needed, but for now 100 max is fine for Supabase usually)
    final rows = await _client.from(_usersTable).select().inFilter('uid', uids);

    return (rows as List).map((e) => UserModel.fromMap(e)).toList();
  }

  Future<void> saveUser(UserModel user) async {
    await _client.from(_usersTable).upsert(user.toMap());
  }

  /// Upload avatar to Supabase Storage
  /// Time: O(n) file size
  Future<String> uploadAvatar({required String uid, required File file}) async {
    final ext = _ext(file.path);
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage
        .from(_bucket)
        .upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true, cacheControl: '3600'),
        );

    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  static String _ext(String path) {
    final i = path.lastIndexOf('.');
    return i == -1 ? 'jpg' : path.substring(i + 1);
  }

  Future<void> updateLastSeen(String uid) async {
    await _client
        .from(_usersTable)
        .update({'last_seen': DateTime.now().toIso8601String()})
        .eq('uid', uid);
  }

  Future<void> updatePrivacySettings(
    String uid,
    String key,
    String value,
  ) async {
    // key should be one of: privacy_last_seen, privacy_profile_photo, privacy_about
    await _client.from(_usersTable).update({key: value}).eq('uid', uid);
  }
}
