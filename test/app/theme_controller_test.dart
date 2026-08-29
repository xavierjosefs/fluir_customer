import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluir_customer/app/theme/theme_controller.dart';
import 'package:fluir_customer/app/theme/theme_preferences_repository.dart';
import 'package:fluir_customer/app/theme/app_theme.dart';

void main() {
  ProviderContainer containerFor(MemoryThemePreferencesRepository repository) =>
      ProviderContainer(
        overrides: [
          themePreferencesRepositoryProvider.overrideWithValue(repository),
        ],
      );

  test('defaults to light when no preference is stored', () {
    final container = containerFor(MemoryThemePreferencesRepository());
    addTearDown(container.dispose);
    expect(container.read(themeControllerProvider), ThemeMode.light);
  });

  test('uses the bootstrap theme and persists toggles', () async {
    final repository = MemoryThemePreferencesRepository(true);
    final container = ProviderContainer(
      overrides: [
        themePreferencesRepositoryProvider.overrideWithValue(repository),
        initialThemeModeProvider.overrideWithValue(ThemeMode.dark),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(themeControllerProvider), ThemeMode.dark);
    await container.read(themeControllerProvider.notifier).setDarkMode(false);
    expect(container.read(themeControllerProvider), ThemeMode.light);
    expect(repository.value, isFalse);
    await container.read(themeControllerProvider.notifier).setDarkMode(true);
    expect(repository.value, isTrue);
  });

  testWidgets('light and dark typography interpolate without an exception', (
    tester,
  ) async {
    var dark = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: Scaffold(
            body: TextButton(
              onPressed: () => setState(() => dark = !dark),
              child: const Text('Cambiar tema'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Cambiar tema'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cambiar tema'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
