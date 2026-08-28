import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/local_notification_service.dart';
import '../../data/mock/mock_auth_repository.dart';
import '../../domain/models/auth_state.dart';

final mockAuthRepositoryProvider = Provider<MockAuthRepository>(
  (ref) => const MockAuthRepository(),
);
final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => FlutterLocalNotificationService(),
);
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  Timer? _countdown;

  @override
  AuthState build() {
    ref.onDispose(() => _countdown?.cancel());
    return const AuthState();
  }

  void begin() => state = state.copyWith(
    status: AuthStatus.editingPhone,
    clearMessage: true,
  );
  void returnToEntry() =>
      state = state.copyWith(status: AuthStatus.entry, clearMessage: true);
  void updatePhone(String phone) =>
      state = state.copyWith(phone: phone, clearMessage: true);
  void updateConsent(bool value) =>
      state = state.copyWith(hasConsent: value, clearMessage: true);
  void updateOtp(String otp) =>
      state = state.copyWith(otp: otp, clearMessage: true);

  Future<void> sendCode() async {
    if (!state.isPhoneValid) {
      state = state.copyWith(
        status: AuthStatus.editingPhone,
        message: 'Ingresa un número dominicano de 10 dígitos.',
      );
      return;
    }
    if (!state.hasConsent) {
      state = state.copyWith(
        status: AuthStatus.editingPhone,
        message:
            'Acepta los Términos y la Política de privacidad para continuar.',
      );
      return;
    }
    _countdown?.cancel();
    state = state.copyWith(
      status: AuthStatus.sendingCode,
      otp: '',
      clearMessage: true,
    );
    try {
      await ref.read(mockAuthRepositoryProvider).sendCode(state.phone);
      state = state.copyWith(
        status: AuthStatus.codeSent,
        remainingSeconds: 30,
        clearMessage: true,
      );
      _startCountdown();
      unawaited(_deliverVerificationNotification());
    } on MockAuthSendException {
      state = state.copyWith(
        status: AuthStatus.sendFailure,
        message: 'Revisa tu conexión e inténtalo nuevamente.',
      );
    }
  }

  void enterOtp() => state = state.copyWith(
    status: AuthStatus.enteringOtp,
    clearMessage: true,
  );

  Future<void> verifyOtp() async {
    if (state.otp.length != 6) {
      state = state.copyWith(
        status: AuthStatus.enteringOtp,
        message: 'Ingresa los 6 dígitos del código.',
      );
      return;
    }
    if (state.status == AuthStatus.expiredOtp) return;
    state = state.copyWith(status: AuthStatus.verifyingOtp, clearMessage: true);
    final isValid = await ref
        .read(mockAuthRepositoryProvider)
        .verifyCode(state.otp);
    state = isValid
        ? state.copyWith(status: AuthStatus.verified, clearMessage: true)
        : state.copyWith(
            status: AuthStatus.invalidOtp,
            message: 'El código que ingresaste no es válido.',
          );
  }

  void editPhone() {
    _countdown?.cancel();
    state = state.copyWith(
      status: AuthStatus.editingPhone,
      otp: '',
      clearMessage: true,
    );
  }

  void expireCode() {
    _countdown?.cancel();
    state = state.copyWith(
      status: AuthStatus.expiredOtp,
      message: 'El código ya no es válido. Solicita uno nuevo para continuar.',
    );
  }

  void _startCountdown() {
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds <= 1) {
        timer.cancel();
        state = state.copyWith(remainingSeconds: 0);
      } else {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      }
    });
  }

  Future<void> _deliverVerificationNotification() async {
    try {
      await ref.read(localNotificationServiceProvider).showVerificationCode();
    } catch (_) {
      // Notification permission or service failures cannot interrupt auth.
    }
  }
}
