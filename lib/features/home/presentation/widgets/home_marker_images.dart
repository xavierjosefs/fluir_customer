import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

abstract final class HomeMarkerImages {
  static Future<Uint8List>? _pickupCache;
  static Future<Uint8List>? _vehicleCache;
  static Future<Uint8List>? _destinationCache;

  static Future<Uint8List> pickup() => _pickupCache ??= _drawPickup();
  static Future<Uint8List> vehicle() => _vehicleCache ??= _drawVehicle();
  static Future<Uint8List> destination() =>
      _destinationCache ??= _drawDestination();

  static Future<Uint8List> _drawPickup() async {
    const size = 68.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawOval(
      const Rect.fromLTWH(12, 51, 44, 9),
      Paint()..color = Colors.black.withValues(alpha: .16),
    );
    canvas.drawCircle(
      const Offset(34, 32),
      28,
      Paint()..color = AppColors.brandBlue.withValues(alpha: .22),
    );
    canvas.drawCircle(const Offset(34, 32), 18, Paint()..color = Colors.white);
    canvas.drawCircle(
      const Offset(34, 32),
      13,
      Paint()..color = AppColors.brandBlue,
    );
    canvas.drawCircle(
      const Offset(30, 28),
      3.5,
      Paint()..color = Colors.white.withValues(alpha: .8),
    );
    return _toPng(recorder, size.toInt(), size.toInt());
  }

  static Future<Uint8List> _drawDestination() async {
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

  static Future<Uint8List> _drawVehicle() async {
    const width = 58.0;
    const height = 64.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawOval(
      const Rect.fromLTWH(12, 51, 34, 8),
      Paint()..color = Colors.black.withValues(alpha: .18),
    );
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 6, 34, 48),
      const Radius.circular(13),
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
        const Rect.fromLTWH(18, 13, 22, 15),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFE8F2F8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 34, 22, 10),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFC7D8E5),
    );
    final wheelPaint = Paint()..color = const Color(0xFF050A12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 15, 6, 11),
        const Radius.circular(3),
      ),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(44, 15, 6, 11),
        const Radius.circular(3),
      ),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 36, 6, 11),
        const Radius.circular(3),
      ),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(44, 36, 6, 11),
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
