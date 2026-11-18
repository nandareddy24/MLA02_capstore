import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// Manages lightweight non-sensitive application preferences via [SharedPreferences].
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  bool get isOnboardingCompleted =>
      _prefs.getBool(AppConstants.prefOnboardingCompleted) ?? false;

  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool(AppConstants.prefOnboardingCompleted, value);
  }

  ThemeMode get themeMode {
    final stored = _prefs.getString(AppConstants.prefThemeMode);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(AppConstants.prefThemeMode, mode.name);
  }

  String? get apiBaseUrl => _prefs.getString(AppConstants.prefApiBaseUrl);

  Future<void> setApiBaseUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      await _prefs.remove(AppConstants.prefApiBaseUrl);
    } else {
      await _prefs.setString(AppConstants.prefApiBaseUrl, url.trim());
    }
  }

  String? get activeUserId => _prefs.getString(AppConstants.prefActiveUserId);

  Future<void> setActiveUserId(String? userId) async {
    if (userId == null || userId.isEmpty) {
      await _prefs.remove(AppConstants.prefActiveUserId);
    } else {
      await _prefs.setString(AppConstants.prefActiveUserId, userId);
    }
  }

  bool get rememberMe => _prefs.getBool(AppConstants.prefRememberMe) ?? true;

  Future<void> setRememberMe(bool value) async {
    await _prefs.setBool(AppConstants.prefRememberMe, value);
  }

  String? get rememberedEmail =>
      _prefs.getString(AppConstants.prefRememberedEmail);

  Future<void> setRememberedEmail(String? email) async {
    if (email == null || email.trim().isEmpty) {
      await _prefs.remove(AppConstants.prefRememberedEmail);
    } else {
      await _prefs.setString(
        AppConstants.prefRememberedEmail,
        email.trim().toLowerCase(),
      );
    }
  }
}
