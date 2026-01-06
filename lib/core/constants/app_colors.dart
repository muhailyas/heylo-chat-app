// Full Brand Color System — Dual Theme Support
// File: lib/core/constants/app_colors.dart

import 'package:flutter/material.dart';

@immutable
final class AppColors {
  const AppColors._();

  static const transparent = Colors.transparent;

  // Primary Brand Palette (Consistent across themes)
  static const primary = Color(0xFF0055FF);
  static const primaryLight = Color(0xFF4C8BFF);
  static const primaryDark = Color(0xFF0039B3);

  // Dark Theme Colors
  static const darkBackground = Color(0xFF0D0E12);
  static const darkSurface = Color(0xFF16181D);
  static const darkCard = Color(0xFF1F2228);
  static const darkBorder = Color(0xFF2E3138);

  // Light Theme Colors
  static const lightBackground = Color(0xFFF8F9FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE5E7EB);

  // Text Colors (Dark Mode)
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkTextDisabled = Color(0xFF64748B);

  // Text Colors (Light Mode)
  static const lightTextPrimary = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF475569);
  static const lightTextDisabled = Color(0xFF94A3B8);

  // UI Feedback
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // Messaging UI
  static const bubbleMe = primary;
  static const bubbleOtherDark = Color(0xFF2E3138);
  static const bubbleOtherLight = Color(0xFFE2E8F0);

  // Brand Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );
}
