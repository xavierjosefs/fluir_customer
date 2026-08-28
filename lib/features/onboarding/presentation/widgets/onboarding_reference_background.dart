import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class OnboardingReferenceBackground extends StatelessWidget {
  const OnboardingReferenceBackground({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: SizedBox.expand(child: CustomPaint(painter: _OnboardingPainter())),
  );
}

class _OnboardingPainter extends CustomPainter {
  const _OnboardingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final topWave = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * .78, 0)
      ..cubicTo(
        size.width * .78,
        size.height * .13,
        size.width * .5,
        size.height * .13,
        size.width * .34,
        size.height * .08,
      )
      ..cubicTo(
        size.width * .18,
        size.height * .02,
        size.width * .15,
        size.height * .22,
        0,
        size.height * .2,
      )
      ..close();
    canvas.drawPath(
      topWave,
      Paint()..color = Colors.white.withValues(alpha: .09),
    );

    final bottomBase = Path()
      ..moveTo(size.width * .32, size.height)
      ..cubicTo(
        size.width * .72,
        size.height * .93,
        size.width * .55,
        size.height * .78,
        size.width * .78,
        size.height * .7,
      )
      ..cubicTo(
        size.width * .9,
        size.height * .65,
        size.width,
        size.height * .7,
        size.width,
        size.height * .7,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      bottomBase,
      Paint()..color = AppColors.brandGreen.withValues(alpha: .78),
    );

    final bottomLayer = Path()
      ..moveTo(size.width * .48, size.height)
      ..cubicTo(
        size.width * .82,
        size.height * .91,
        size.width * .62,
        size.height * .79,
        size.width * .9,
        size.height * .76,
      )
      ..cubicTo(
        size.width * .96,
        size.height * .75,
        size.width,
        size.height * .77,
        size.width,
        size.height * .77,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      bottomLayer,
      Paint()..color = AppColors.brandGreen.withValues(alpha: .45),
    );
  }

  @override
  bool shouldRepaint(covariant _OnboardingPainter oldDelegate) => false;
}
