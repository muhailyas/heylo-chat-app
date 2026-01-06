import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

@immutable
class AppThemeConfig {
  final ThemeMode themeMode;
  final Color primaryColor;
  final double borderRadius;
  final double primaryOpacity;

  // Dark Mode Palette
  final Color darkBackground;
  final Color darkSurface;
  final Color darkCard;

  // Light Mode Palette
  final Color lightBackground;
  final Color lightSurface;
  final Color lightCard;

  const AppThemeConfig({
    required this.themeMode,
    required this.primaryColor,
    required this.borderRadius,
    this.primaryOpacity = 1.0,
    required this.darkBackground,
    required this.darkSurface,
    required this.darkCard,
    required this.lightBackground,
    required this.lightSurface,
    required this.lightCard,
  });

  factory AppThemeConfig.defaultConfig() {
    return const AppThemeConfig(
      themeMode: ThemeMode.dark,
      primaryColor: AppColors.primary,
      borderRadius: 16.0,
      primaryOpacity: 1.0,
      darkBackground: AppColors.darkBackground,
      darkSurface: AppColors.darkSurface,
      darkCard: AppColors.darkCard,
      lightBackground: AppColors.lightBackground,
      lightSurface: AppColors.lightSurface,
      lightCard: AppColors.lightCard,
    );
  }

  AppThemeConfig copyWith({
    ThemeMode? themeMode,
    Color? primaryColor,
    double? borderRadius,
    double? primaryOpacity,
    Color? darkBackground,
    Color? darkSurface,
    Color? darkCard,
    Color? lightBackground,
    Color? lightSurface,
    Color? lightCard,
  }) {
    return AppThemeConfig(
      themeMode: themeMode ?? this.themeMode,
      primaryColor: primaryColor ?? this.primaryColor,
      borderRadius: borderRadius ?? this.borderRadius,
      primaryOpacity: primaryOpacity ?? this.primaryOpacity,
      darkBackground: darkBackground ?? this.darkBackground,
      darkSurface: darkSurface ?? this.darkSurface,
      darkCard: darkCard ?? this.darkCard,
      lightBackground: lightBackground ?? this.lightBackground,
      lightSurface: lightSurface ?? this.lightSurface,
      lightCard: lightCard ?? this.lightCard,
    );
  }
}
