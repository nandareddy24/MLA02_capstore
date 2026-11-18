import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/providers.dart';

/// Controls and persists the active Material 3 [ThemeMode].
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return prefs.themeMode;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(preferencesServiceProvider).setThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
