import 'package:fluir_customer/app/theme/app_colors.dart';
import 'package:fluir_customer/features/splash/presentation/screens/splash_screen.dart';
import 'package:fluir_customer/features/splash/presentation/widgets/fluir_flow_mark.dart';
import 'package:fluir_customer/shared/widgets/fluir_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the splash shows the official wordmark on the brand plate', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onCompleted: () {})),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FluirWordmark), findsOneWidget);
    final wordmark = tester.widget<FluirWordmark>(find.byType(FluirWordmark));
    expect(wordmark.color, AppColors.logoWordmark);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppColors.logoPlate,
    );
  });

  testWidgets('it always hands over, and only once', (tester) async {
    var handovers = 0;
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onCompleted: () => handovers++)),
    );

    expect(handovers, 0);
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();

    expect(handovers, 1);
  });

  testWidgets('reduced motion skips the animation but still continues', (
    tester,
  ) async {
    var handovers = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: SplashScreen(onCompleted: () => handovers++)),
      ),
    );
    await tester.pump();

    // The brand moment is already at its final frame.
    final mark = tester.widget<FluirFlowMark>(find.byType(FluirFlowMark));
    expect(mark.progress, 1);

    await tester.pump(SplashScreen.reducedMotionDuration);
    await tester.pumpAndSettle();
    expect(handovers, 1);
  });

  testWidgets('the flow mark grows with its progress', (tester) async {
    Future<Size> strokeAt(double progress) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: FluirFlowMark(progress: progress)),
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byType(FractionallySizedBox));
    }

    final early = await strokeAt(.3);
    final late = await strokeAt(1);

    expect(late.width, greaterThan(early.width));
  });
}
