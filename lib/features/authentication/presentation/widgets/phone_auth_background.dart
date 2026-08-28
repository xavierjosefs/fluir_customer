import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class PhoneAuthBackground extends StatelessWidget {
  const PhoneAuthBackground({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: SizedBox.expand(child: CustomPaint(painter: _PhoneAuthPainter())),
  );
}

class _PhoneAuthPainter extends CustomPainter {
  const _PhoneAuthPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final topLeft = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * .32, 0)
      ..cubicTo(
        size.width * .3,
        size.height * .08,
        size.width * .16,
        size.height * .07,
        0,
        size.height * .16,
      )
      ..close();
    canvas.drawPath(topLeft, Paint()..color = AppColors.brandBlue);
    final topRight = Path()
      ..moveTo(size.width * .87, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * .14)
      ..cubicTo(
        size.width * .91,
        size.height * .13,
        size.width * .83,
        size.height * .08,
        size.width * .87,
        0,
      )
      ..close();
    canvas.drawPath(
      topRight,
      Paint()..color = AppColors.brandGreen.withValues(alpha: .72),
    );

    final greenWave = Path()
      ..moveTo(0, size.height * .88)
      ..cubicTo(
        size.width * .2,
        size.height * .8,
        size.width * .35,
        size.height * .98,
        size.width * .61,
        size.height * .96,
      )
      ..cubicTo(
        size.width * .75,
        size.height * .95,
        size.width * .78,
        size.height,
        size.width * .84,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      greenWave,
      Paint()..color = AppColors.brandGreen.withValues(alpha: .72),
    );

    final blueWave = Path()
      ..moveTo(size.width * .7, size.height)
      ..cubicTo(
        size.width * .76,
        size.height * .9,
        size.width * .76,
        size.height * .78,
        size.width,
        size.height * .74,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      blueWave,
      Paint()..color = AppColors.brandBlue.withValues(alpha: .9),
    );
    final blueLayer = Path()
      ..moveTo(size.width * .82, size.height)
      ..cubicTo(
        size.width * .86,
        size.height * .91,
        size.width * .88,
        size.height * .83,
        size.width,
        size.height * .81,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      blueLayer,
      Paint()..color = Colors.white.withValues(alpha: .12),
    );
  }

  @override
  bool shouldRepaint(covariant _PhoneAuthPainter oldDelegate) => false;
}
