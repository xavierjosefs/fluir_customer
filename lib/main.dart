import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/system_ui.dart';
import 'app/theme/theme_controller.dart';
import 'app/theme/theme_preferences_repository.dart';
import 'core/config/mapbox_configuration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppSystemUi.configure();
  MapboxConfiguration.initialize();
  final preferences = await SharedPreferences.getInstance();
  final repository = SharedPreferencesThemePreferencesRepository(preferences);
  final darkMode = await repository.loadDarkMode() ?? false;
  runApp(
    ProviderScope(
      overrides: [
        themePreferencesRepositoryProvider.overrideWithValue(repository),
        initialThemeModeProvider.overrideWithValue(
          darkMode ? ThemeMode.dark : ThemeMode.light,
        ),
      ],
      child: const FluirApp(),
    ),
  );
}
