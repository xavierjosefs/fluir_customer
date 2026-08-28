enum AuthStatus {
  entry,
  editingPhone,
  sendingCode,
  codeSent,
  enteringOtp,
  verifyingOtp,
  invalidOtp,
  expiredOtp,
  sendFailure,
  verified,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.entry,
    this.phone = '',
    this.hasConsent = false,
    this.otp = '',
    this.remainingSeconds = 30,
    this.message,
  });

  final AuthStatus status;
  final String phone;
  final bool hasConsent;
  final String otp;
  final int remainingSeconds;
  final String? message;

  String get formattedPhone => phone.length == 10
      ? '${phone.substring(0, 3)} ${phone.substring(3, 6)} ${phone.substring(6)}'
      : phone;
  String get maskedPhone => phone.length == 10
      ? '+1 (${phone.substring(0, 3)}) ***-${phone.substring(6)}'
      : '+1 ••••';
  bool get isPhoneValid => phone.length == 10;

  AuthState copyWith({
    AuthStatus? status,
    String? phone,
    bool? hasConsent,
    String? otp,
    int? remainingSeconds,
    String? message,
    bool clearMessage = false,
  }) => AuthState(
    status: status ?? this.status,
    phone: phone ?? this.phone,
    hasConsent: hasConsent ?? this.hasConsent,
    otp: otp ?? this.otp,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    message: clearMessage ? null : message ?? this.message,
  );
}
