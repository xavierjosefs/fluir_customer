import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_preferences_repository.dart';

final themePreferencesRepositoryProvider = Provider<ThemePreferencesRepository>(
  (ref) => MemoryThemePreferencesRepository(),
);

final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.light);

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ref.watch(initialThemeModeProvider);
  }

  Future<void> setDarkMode(bool enabled) async {
    state = enabled ? ThemeMode.dark : ThemeMode.light;
    await ref.read(themePreferencesRepositoryProvider).saveDarkMode(enabled);
  }
}
