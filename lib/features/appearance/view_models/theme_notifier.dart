import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_theme_config.dart';

class ThemeNotifier extends Notifier<AppThemeConfig> {
  static const _keyThemeMode = 'theme_mode';
  static const _keyPrimary = 'theme_primary';
  static const _keyDarkBackground = 'theme_dark_bg';
  static const _keyDarkCard = 'theme_dark_card';
  static const _keyLightBackground = 'theme_light_bg';
  static const _keyRadius = 'theme_radius';
  static const _keyOpacity = 'theme_opacity';

  @override
  AppThemeConfig build() {
    _loadSettings();
    return AppThemeConfig.defaultConfig();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_keyThemeMode);
    final p = prefs.getInt(_keyPrimary);
    final db = prefs.getInt(_keyDarkBackground);
    final dc = prefs.getInt(_keyDarkCard);
    final lb = prefs.getInt(_keyLightBackground);
    final r = prefs.getDouble(_keyRadius);

    state = state.copyWith(
      themeMode: modeIndex != null ? ThemeMode.values[modeIndex] : null,
      primaryColor: p != null ? Color(p) : null,
      darkBackground: db != null ? Color(db) : null,
      darkCard: dc != null ? Color(dc) : null,
      lightBackground: lb != null ? Color(lb) : null,
      borderRadius: r,
      primaryOpacity: prefs.getDouble(_keyOpacity),
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, state.themeMode.index);
    await prefs.setInt(_keyPrimary, state.primaryColor.value);
    await prefs.setInt(_keyDarkBackground, state.darkBackground.value);
    await prefs.setInt(_keyDarkCard, state.darkCard.value);
    await prefs.setInt(_keyLightBackground, state.lightBackground.value);
    await prefs.setDouble(_keyRadius, state.borderRadius);
    await prefs.setDouble(_keyOpacity, state.primaryOpacity);
  }

  void toggleThemeMode() {
    final newMode = state.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    state = state.copyWith(themeMode: newMode);
    _saveSettings();
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _saveSettings();
  }

  void setPrimaryColor(Color color) {
    state = state.copyWith(primaryColor: color);
    _saveSettings();
  }

  void setBorderRadius(double radius) {
    state = state.copyWith(borderRadius: radius);
    _saveSettings();
  }

  void setPrimaryOpacity(double opacity) {
    state = state.copyWith(primaryOpacity: opacity);
    _saveSettings();
  }

  void resetToDefault() {
    state = AppThemeConfig.defaultConfig();
    _saveSettings();
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeConfig>(
  ThemeNotifier.new,
);
