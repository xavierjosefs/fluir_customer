import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/backend_providers.dart';
import '../../data/customer_auth_repository.dart';

enum CustomerSessionStatus { signedOut, signingIn, signedIn, expired }

/// The customer's backend session, as the UI may know it: no tokens, no phone.
@immutable
class CustomerSession {
  const CustomerSession({
    this.status = CustomerSessionStatus.signedOut,
    this.customerId,
    this.message,
  });

  final CustomerSessionStatus status;
  final int? customerId;

  /// User-safe Spanish explanation of the last failure or expiry.
  final String? message;

  bool get isSignedIn =>
      status == CustomerSessionStatus.signedIn && customerId != null;
}

final customerAuthRepositoryProvider = Provider<CustomerAuthRepository?>((ref) {
  final api = ref.watch(fluirApiClientProvider);
  return api == null ? null : CustomerAuthRepository(api);
});

/// Debug demo builds with demo credentials show a one-tap demo sign-in.
final demoSignInAvailableProvider = Provider<bool>(
  (ref) =>
      ref.watch(demoCustomerCredentialsProvider) != null &&
      ref.watch(customerAuthRepositoryProvider) != null,
);

final customerSessionProvider =
    NotifierProvider<CustomerSessionController, CustomerSession>(
      CustomerSessionController.new,
    );

/// Demo sign-in, restore on launch and expiry.
///
/// An expiry only ends the session: the ride state (and its trip id) stays
/// where it is, and the ride controller reconciles the trip once the customer
/// signs in again. A 401 never cancels a trip.
class CustomerSessionController extends Notifier<CustomerSession> {
  @override
  CustomerSession build() {
    ref.listen(sessionExpirationsProvider, (previous, next) {
      if (previous != next) _expire();
    });
    final store = ref.read(sessionStoreProvider);
    if (ref.read(fluirApiClientProvider) != null && store.hasSession) {
      return CustomerSession(
        status: CustomerSessionStatus.signedIn,
        customerId: store.userId,
      );
    }
    return const CustomerSession();
  }

  bool get canSignInWithDemoCustomer =>
      ref.read(demoCustomerCredentialsProvider) != null &&
      ref.read(customerAuthRepositoryProvider) != null;

  Future<bool> signInWithDemoCustomer() async {
    final credentials = ref.read(demoCustomerCredentialsProvider);
    final auth = ref.read(customerAuthRepositoryProvider);
    if (credentials == null ||
        auth == null ||
        state.status == CustomerSessionStatus.signingIn) {
      return false;
    }
    state = const CustomerSession(status: CustomerSessionStatus.signingIn);
    final store = ref.read(sessionStoreProvider);
    try {
      await auth.sendCode(
        country: credentials.country,
        phone: credentials.phone,
      );
      final tokens = await auth.login(
        country: credentials.country,
        phone: credentials.phone,
        verificationCode: credentials.verificationCode,
      );
      await store.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      final customerId = await auth.currentUserId();
      await store.saveUserId(customerId);
      if (!ref.mounted) return false;
      _log('Signed in.');
      state = CustomerSession(
        status: CustomerSessionStatus.signedIn,
        customerId: customerId,
      );
      return true;
    } on ApiException catch (error) {
      await store.clear();
      if (!ref.mounted) return false;
      _log('Sign-in failed: ${error.failure.name}.');
      state = CustomerSession(message: error.userMessage);
      return false;
    }
  }

  Future<void> signOut() async {
    final store = ref.read(sessionStoreProvider);
    try {
      await ref
          .read(customerAuthRepositoryProvider)
          ?.logout(store.refreshToken);
    } on ApiException {
      // The local session ends either way.
    }
    await store.clear();
    if (ref.mounted) state = const CustomerSession();
  }

  void _expire() {
    if (state.status == CustomerSessionStatus.signedOut) return;
    _log('Session expired.');
    state = const CustomerSession(
      status: CustomerSessionStatus.expired,
      message: 'Tu sesión expiró. Inicia sesión de nuevo para continuar.',
    );
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[FluirSession] $message');
  }
}
