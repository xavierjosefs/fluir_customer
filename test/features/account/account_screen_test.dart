import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluir_customer/app/theme/theme_controller.dart';
import 'package:fluir_customer/app/theme/theme_preferences_repository.dart';
import 'package:fluir_customer/features/account/presentation/screens/account_placeholder_screen.dart';

void main() {
  testWidgets('renders account settings and changes the global theme', (
    tester,
  ) async {
    final preferences = MemoryThemePreferencesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themePreferencesRepositoryProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AccountPlaceholderScreen()),
        ),
      ),
    );
    for (final label in [
      'Federico De la Cruz',
      'Modo oscuro',
      'Notificaciones',
      'Métodos de pago',
      'Perfil',
      'Seguridad',
      'Privacidad',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(preferences.value, isTrue);
  });
}
