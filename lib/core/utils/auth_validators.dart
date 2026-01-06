// Auth Field Validators (Optimized)
// File: lib/core/utils/validators.dart

import 'package:flutter/material.dart';

@immutable
final class Validators {
  const Validators._();

  /// Full Name — Only letters & space | Min 3 chars
  static String? fullName(String value) {
    final v = value.trim();
    if (v.isEmpty) return "Name is required";
    if (!RegExp(r"^[A-Za-z][A-Za-z\s]{2,}$").hasMatch(v)) {
      return "Enter a valid name";
    }
    return null;
  }

  /// Phone — India format
  static String? validatePhone(String value) {
    final v = value.replaceAll(RegExp(r'\s+'), "");
    if (v.isEmpty) return "Phone number is required";
    if (!RegExp(r"^\+?91?[0-9]{10}$").hasMatch(v)) {
      return "Invalid phone number";
    }
    return null;
  }

  /// Required Email
  static String? requiredEmail(String value) {
    final v = value.trim();
    if (v.isEmpty) return "Email is required";
    if (!_emailRegex.hasMatch(v)) return "Invalid email format";
    return null;
  }

  /// Optional Email
  static String? optionalEmail(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    if (!_emailRegex.hasMatch(v)) return "Invalid email format";
    return null;
  }

  static final _emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$");
}
