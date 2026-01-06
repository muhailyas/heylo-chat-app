// Phone login using Firestore (NO Firebase Auth, NO reCAPTCHA).
// Flow: send OTP → verify OTP → create/get user document → login.
// File: lib/features/auth/data/firestore_phone_auth.dart

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePhoneAuth {
  FirestorePhoneAuth() : _db = FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // -----------------------
  // Generate secure OTP
  // -----------------------
  String _generateOtp() {
    final rand = Random.secure();
    return (100000 + rand.nextInt(900000)).toString(); // 6-digit OTP
  }

  // -----------------------
  // Send OTP (via SMS API)
  // -----------------------
  Future<String> sendOtp(String phone) async {
    if (phone.isEmpty || phone.length < 8) {
      throw Exception('Invalid phone number');
    }

    final otp = _generateOtp();
    final expiresAt = DateTime.now()
        .add(const Duration(minutes: 3))
        .millisecondsSinceEpoch;

    await _db.collection('otp_requests').doc(phone).set({
      'otp': otp,
      'expiresAt': expiresAt,
    });

    // NOTE: Send OTP using your SMS provider API (NOT Firebase Auth)
    // Example: call your backend that triggers SMS.
    // Never store OTP in client logs.

    return otp; // return only for testing UI; remove in production
  }

  // -----------------------
  // Verify OTP
  // -----------------------
  Future<bool> verifyOtp(String phone, String code) async {
    final doc = await _db.collection('otp_requests').doc(phone).get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    final otp = data['otp'];
    final expiresAt = data['expiresAt'] as int;

    if (DateTime.now().millisecondsSinceEpoch > expiresAt) return false;
    if (otp != code) return false;

    return true;
  }

  // -----------------------
  // Create or fetch user
  // -----------------------
  Future<Map<String, dynamic>> loginOrRegister({
    required String phone,
    required String name,
    String? email,
  }) async {
    final userRef = _db.collection('users').doc(phone);
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      // Register new user
      final userData = {
        'phone': phone,
        'name': name,
        'email': email ?? '',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
      await userRef.set(userData);
      return userData;
    }

    // Return existing user
    return snapshot.data()!;
  }
}
