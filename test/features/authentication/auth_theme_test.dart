import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluir_customer/app/theme/app_theme.dart';
import 'package:fluir_customer/features/authentication/presentation/screens/otp_screen.dart';
import 'package:fluir_customer/features/authentication/presentation/screens/phone_number_screen.dart';

void main() {
  testWidgets(
    'phone authentication keeps readable themed surfaces in dark mode',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: PhoneNumberScreen(),
          ),
        ),
      );

      expect(find.text('Número de celular'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(PhoneNumberScreen))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'OTP keeps its six themed cells and recovery actions in dark mode',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: OtpScreen(),
          ),
        ),
      );

      expect(find.text('Ingresa el código'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('Reenviar en'), findsOneWidget);
      expect(find.text('Cambiar número'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
