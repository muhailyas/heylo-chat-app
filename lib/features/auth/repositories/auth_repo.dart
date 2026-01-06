// // Firestore-based auth repository (send/verify OTP, create/get user)
// // File: lib/features/auth/repositories/firestore_auth_repo.dart

// import 'dart:convert';
// import 'dart:math';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:crypto/crypto.dart';

// import '../../../core/firebase/firebase_service.dart';

// class FirestoreAuthRepo {
//   FirestoreAuthRepo({FirebaseFirestore? firestore})
//     : _db = firestore ?? FirebaseService.instance.firestore;

//   final FirebaseFirestore _db;

//   // Generate 6-digit OTP securely
//   String _generateOtp() {
//     final r = Random.secure();
//     return (100000 + r.nextInt(900000)).toString();
//   }

//   // Hash OTP with SHA256 before storing
//   String _hash(String input) => sha256.convert(utf8.encode(input)).toString();

//   /// Send OTP: stores hashed OTP + expiry in Firestore under collection 'otp_requests'
//   /// Returns the plaintext OTP only for dev/debug (remove before production).
//   Future<String> sendOtp({
//     required String phone,
//     Duration ttl = const Duration(minutes: 3),
//   }) async {
//     if (phone.isEmpty) {
//       throw ArgumentError.value(phone, 'phone', 'Phone cannot be empty');
//     }
//     if (phone.length < 7) {
//       throw ArgumentError.value(phone, 'phone', 'Phone seems invalid');
//     }

//     final otp = _generateOtp();
//     final hashed = _hash(otp);
//     final expiresAt = DateTime.now().add(ttl).millisecondsSinceEpoch;

//     final docRef = _db.collection('otp_requests').doc(phone);
//     await docRef.set({
//       'otpHash': hashed,
//       'expiresAt': expiresAt,
//       'createdAt': DateTime.now().millisecondsSinceEpoch,
//       'attempts': 0,
//     }, SetOptions(merge: true));

//     // NOTE: integrate your SMS provider (server/cloud-function) to actually send 'otp' to the phone.
//     // Returning OTP here only eases local development and automated tests. Remove for production.
//     return otp;
//   }

//   /// Verify OTP: compares hashed OTP and expiry. If valid, deletes the OTP doc.
//   Future<bool> verifyOtp({required String phone, required String otp}) async {
//     final docRef = _db.collection('otp_requests').doc(phone);
//     final snap = await docRef.get();
//     if (!snap.exists) return false;

//     final data = snap.data()!;
//     final storedHash = data['otpHash'] as String?;
//     final expiresAt = data['expiresAt'] as int? ?? 0;

//     if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
//       // expired - clean up
//       await docRef.delete();
//       return false;
//     }

//     if (storedHash == null) return false;
//     final incomingHash = _hash(otp);
//     if (incomingHash != storedHash) {
//       // increment attempts counter (defence-in-depth)
//       await docRef.update({'attempts': FieldValue.increment(1)});
//       return false;
//     }

//     // success - remove otp doc
//     await docRef.delete();
//     return true;
//   }

//   /// Create or return existing user doc. Uses phone as document id (UID).
//   Future<String> createOrGetUser({required String phone}) async {
//     final userRef = _db.collection('users').doc(phone);
//     final snap = await userRef.get();
//     if (!snap.exists) {
//       final data = {
//         'uid': phone,
//         'phone': phone,
//         'name': null,
//         'email': null,
//         'avatarUrl': null,
//         'createdAt': DateTime.now().millisecondsSinceEpoch,
//         'lastSeen': DateTime.now().millisecondsSinceEpoch,
//       };
//       await userRef.set(data);
//       return phone;
//     } else {
//       await userRef.update({'lastSeen': DateTime.now().millisecondsSinceEpoch});
//       return snap.id;
//     }
//   }
// }
// Supabase DB-based auth repository (NO Supabase Auth, NO SMS service)
// OTP stored + verified purely via database (same model as Firestore version)
// File: lib/features/auth/repositories/supabase_db_auth_repo.dart

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDbAuthRepo {
  SupabaseDbAuthRepo(this._client);

  final SupabaseClient _client;

  static const String _otpTable = 'otp_requests';
  static const String _usersTable = 'users';

  // O(1)
  String _generateOtp() {
    final r = Random.secure();
    return (100000 + r.nextInt(900000)).toString();
  }

  // O(n)
  String _hash(String input) => sha256.convert(utf8.encode(input)).toString();

  /// Send OTP (DB only). Returns OTP for dev/testing.
  Future<String> sendOtp({
    required String phone,
    Duration ttl = const Duration(minutes: 3),
  }) async {
    if (phone.isEmpty || phone.length < 7) {
      throw ArgumentError.value(phone, 'phone', 'Invalid phone number');
    }

    final otp = _generateOtp();
    final hashed = _hash(otp);
    final expiresAt = DateTime.now().add(ttl);

    await _client.from(_otpTable).upsert({
      'phone': phone,
      'otp_hash': hashed,
      'expires_at': expiresAt.toIso8601String(),
      'attempts': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    // NOTE: integrate SMS provider on backend
    return otp; // DEV ONLY
  }

  /// Verify OTP against DB
  /// Time: O(1)
  Future<bool> verifyOtp({required String phone, required String otp}) async {
    final row = await _client
        .from(_otpTable)
        .select()
        .eq('phone', phone)
        .maybeSingle();

    if (row == null) return false;

    final expiresAt = DateTime.parse(row['expires_at'] as String);
    if (DateTime.now().isAfter(expiresAt)) {
      await _client.from(_otpTable).delete().eq('phone', phone);
      return false;
    }

    final storedHash = row['otp_hash'] as String?;
    if (storedHash == null || _hash(otp) != storedHash) {
      await _client
          .from(_otpTable)
          .update({'attempts': (row['attempts'] as int) + 1})
          .eq('phone', phone);
      return false;
    }

    await _client.from(_otpTable).delete().eq('phone', phone);
    return true;
  }

  /// Create or return user (phone-based UID)
  /// Time: O(1)
  Future<String> createOrGetUser({required String phone}) async {
    final row = await _client
        .from(_usersTable)
        .select('uid')
        .eq('uid', phone)
        .maybeSingle();

    if (row == null) {
      await _client.from(_usersTable).insert({
        'uid': phone,
        'phone': phone,
        'name': null,
        'email': null,
        'avatar_url': null,
        'created_at': DateTime.now().toIso8601String(),
        'last_seen': DateTime.now().toIso8601String(),
      });
      return phone;
    }

    await _client
        .from(_usersTable)
        .update({'last_seen': DateTime.now().toIso8601String()})
        .eq('uid', phone);

    return phone;
  }

  // ───────────────── Linked Devices ─────────────────

  Future<String?> registerDevice({
    required String userId,
    required String deviceId,
    required String name,
    required String platform,
  }) async {
    final res = await _client
        .from('user_devices')
        .upsert({
          'user_id': userId,
          'device_id': deviceId,
          'device_name': name,
          'platform': platform,
          'last_active': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id, device_id')
        .select('id')
        .single();

    return res['id']?.toString();
  }

  Future<List<Map<String, dynamic>>> getLinkedDevices(String userId) async {
    final list = await _client
        .from('user_devices')
        .select()
        .eq('user_id', userId)
        .order('last_active', ascending: false);
    return List<Map<String, dynamic>>.from(list);
  }

  Future<void> logoutDevice({
    required String userId,
    required String deviceId,
  }) async {
    await _client
        .from('user_devices')
        .delete()
        .eq('user_id', userId)
        .eq('device_id', deviceId);
  }
}
