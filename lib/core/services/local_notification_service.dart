import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class LocalNotificationService {
  Future<void> showVerificationCode();
}

class FlutterLocalNotificationService implements LocalNotificationService {
  FlutterLocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'fluir_verification',
    'Verificación de cuenta',
    description: 'Códigos de verificación de Fluir',
    importance: Importance.defaultImportance,
  );

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialization;

  @override
  Future<void> showVerificationCode() async {
    try {
      await _initialize();
      await Future<void>.delayed(const Duration(seconds: 1));
      await _plugin.show(
        id: 1001,
        title: 'Fluir',
        body: 'Tu código de verificación es 123456',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'fluir_verification',
            'Verificación de cuenta',
            channelDescription: 'Códigos de verificación de Fluir',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {
      // Local notification availability never blocks the mocked OTP flow.
    }
  }

  Future<void> _initialize() => _initialization ??= _initializeSafely();

  Future<void> _initializeSafely() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }
}
