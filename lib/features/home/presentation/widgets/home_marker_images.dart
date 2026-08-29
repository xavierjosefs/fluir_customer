import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

abstract final class HomeMarkerImages {
  static Future<Uint8List> pickup() async {
    const size = 56.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawOval(
      const Rect.fromLTWH(14, 43, 28, 8),
      Paint()..color = Colors.black.withValues(alpha: .16),
    );
    final pin = Path()
      ..moveTo(28, 4)
      ..cubicTo(14, 4, 8, 15, 8, 27)
      ..cubicTo(8, 38, 20, 47, 28, 53)
      ..cubicTo(36, 47, 48, 38, 48, 27)
      ..cubicTo(48, 15, 42, 4, 28, 4)
      ..close();
    canvas.drawPath(pin, Paint()..color = AppColors.brandGreen);
    canvas.drawPath(
      pin,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    canvas.drawCircle(Offset(size / 2, 26), 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(size / 2, 26),
      5,
      Paint()..color = AppColors.brandGreen,
    );
    return _toPng(recorder, size.toInt(), size.toInt());
  }

  static Future<Uint8List> destination() async {
    const size = 54.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawOval(
      const Rect.fromLTWH(13, 43, 28, 7),
      Paint()..color = Colors.black.withValues(alpha: .14),
    );
    canvas.drawCircle(const Offset(27, 26), 21, Paint()..color = Colors.white);
    canvas.drawCircle(
      const Offset(27, 26),
      17,
      Paint()..color = AppColors.brandBlue,
    );

    final pole = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(22, 17), const Offset(22, 34), pole);
    final flag = Path()
      ..moveTo(23, 18)
      ..lineTo(34, 20)
      ..lineTo(29, 25)
      ..lineTo(23, 24)
      ..close();
    canvas.drawPath(flag, Paint()..color = Colors.white);

    return _toPng(recorder, size.toInt(), size.toInt());
  }

  static Future<Uint8List> vehicle() async {
    const width = 42.0;
    const height = 54.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawOval(
      const Rect.fromLTWH(9, 40, 24, 8),
      Paint()..color = Colors.black.withValues(alpha: .18),
    );
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(8, 5, 26, 39),
      const Radius.circular(11),
    );
    canvas.drawRRect(body, Paint()..color = AppColors.navy);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 11, 18, 12),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFE8F2F8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 28, 18, 8),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFC7D8E5),
    );
    final wheelPaint = Paint()..color = const Color(0xFF050A12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 12, 5, 10),
        const Radius.circular(3),
      ),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 12, 5, 10),
        const Radius.circular(3),
      ),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 29, 5, 10),
        const Radius.circular(3),
      ),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 29, 5, 10),
        const Radius.circular(3),
      ),
      wheelPaint,
    );
    return _toPng(recorder, width.toInt(), height.toInt());
  }

  static Future<Uint8List> _toPng(
    ui.PictureRecorder recorder,
    int width,
    int height,
  ) async {
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}
