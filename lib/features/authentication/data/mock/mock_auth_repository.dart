enum MockAuthScenario { normal, sendFailure }

class MockAuthRepository {
  const MockAuthRepository({
    this.scenario = MockAuthScenario.normal,
    this.delay = const Duration(milliseconds: 500),
  });

  final MockAuthScenario scenario;
  final Duration delay;
  static const validOtp = '123456';

  Future<void> sendCode(String phone) async {
    await Future<void>.delayed(delay);
    if (scenario == MockAuthScenario.sendFailure) {
      throw const MockAuthSendException();
    }
  }

  Future<bool> verifyCode(String code) async {
    await Future<void>.delayed(delay);
    return code == validOtp;
  }
}

class MockAuthSendException implements Exception {
  const MockAuthSendException();
}
