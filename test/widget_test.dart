import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluir_customer/app/app.dart';

void main() {
  testWidgets('starts with the four main navigation destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FluirApp()));
    await tester.pumpAndSettle();

    expect(find.text('Inicio'), findsAtLeastNWidgets(1));
    expect(find.text('Actividad'), findsOneWidget);
    expect(find.text('Pagos'), findsOneWidget);
    expect(find.text('Cuenta'), findsOneWidget);
  });
}
