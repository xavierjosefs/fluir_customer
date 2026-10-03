import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/payment_method.dart';
import '../../domain/payment_gateway_exception.dart';
import '../../domain/repositories/payment_method_repository.dart';
import '../payments_providers.dart';

enum PaymentMethodsStatus {
  loading,
  ready,
  error,

  /// The gateway refused to list the saved cards, but this build may still
  /// start a card setup. No card is shown and the wallet is not claimed to be
  /// empty: the app simply does not know what is stored.
  listingUnavailable,
}

@immutable
class PaymentMethodsState {
  const PaymentMethodsState({
    this.status = PaymentMethodsStatus.loading,
    this.methods = const [],
    this.errorMessage,
    this.isRecoverable = true,
    this.busyMethodId,
  });

  final PaymentMethodsStatus status;
  final List<PaymentMethod> methods;
  final String? errorMessage;
  final bool isRecoverable;

  /// Id of the card currently being updated or removed.
  final String? busyMethodId;

  /// Only a successful read can say the wallet is empty.
  bool get isEmpty => status == PaymentMethodsStatus.ready && methods.isEmpty;

  /// Card management is only offered for cards the app actually read.
  bool get canManageMethods =>
      status == PaymentMethodsStatus.ready && methods.isNotEmpty;

  PaymentMethodsState copyWith({
    PaymentMethodsStatus? status,
    List<PaymentMethod>? methods,
    String? errorMessage,
    bool? isRecoverable,
    String? busyMethodId,
    bool clearError = false,
    bool clearBusy = false,
  }) => PaymentMethodsState(
    status: status ?? this.status,
    methods: methods ?? this.methods,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    isRecoverable: isRecoverable ?? this.isRecoverable,
    busyMethodId: clearBusy ? null : busyMethodId ?? this.busyMethodId,
  );
}

/// Owns the saved-card list. Every mutation is re-read from the gateway so the
/// screen never shows an outcome the backend did not record.
class PaymentMethodsController extends Notifier<PaymentMethodsState> {
  @override
  PaymentMethodsState build() {
    Future.microtask(load);
    return const PaymentMethodsState();
  }

  PaymentMethodRepository get _repository =>
      ref.read(paymentMethodRepositoryProvider);

  Future<void> load() async {
    if (!ref.mounted) return;
    state = state.copyWith(
      status: PaymentMethodsStatus.loading,
      clearError: true,
      clearBusy: true,
    );
    await _readMethods();
  }

  /// Reloads without flipping the screen back to its full loading state.
  Future<void> refresh() => _readMethods();

  Future<void> setDefault(String paymentMethodId) => _mutate(
    paymentMethodId,
    () => _repository.setDefaultMethod(paymentMethodId),
  );

  /// Logical revocation: the gateway stops the card, it is never deleted.
  Future<void> revoke(String paymentMethodId) =>
      _mutate(paymentMethodId, () => _repository.revokeMethod(paymentMethodId));

  Future<void> _mutate(
    String paymentMethodId,
    Future<void> Function() action,
  ) async {
    if (state.busyMethodId != null) return;
    // A card can only be managed when the app actually read it from the
    // gateway. Without a loaded list there is nothing legitimate to act on.
    if (!state.methods.any((method) => method.id == paymentMethodId)) {
      return;
    }
    state = state.copyWith(busyMethodId: paymentMethodId, clearError: true);
    try {
      await action();
    } on PaymentGatewayException catch (error) {
      if (!ref.mounted) return;
      if (error.failure == PaymentGatewayFailure.notFound) {
        // The gateway no longer knows this card, so the list on screen is
        // stale. Re-read it first, then explain what happened.
        await _readMethods();
        if (!ref.mounted) return;
      }
      state = state.copyWith(
        errorMessage: error.message,
        isRecoverable: error.isRecoverable,
        clearBusy: true,
      );
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(clearBusy: true);
    await _readMethods();
  }

  Future<void> _readMethods() async {
    try {
      final methods = await _repository.loadActiveMethods();
      if (!ref.mounted) return;
      state = state.copyWith(
        status: PaymentMethodsStatus.ready,
        methods: _sorted(methods),
        clearError: true,
        clearBusy: true,
      );
    } on PaymentGatewayException catch (error) {
      if (!ref.mounted) return;
      // The multi-card API is internal-only, so a local sandbox build is
      // refused the listing while it can still start a card setup. Degrade
      // instead of blocking — but never invent cards and never claim the
      // wallet is empty.
      final canStillAddCard =
          error.failure == PaymentGatewayFailure.unauthorized &&
          ref.read(canAddCardWithoutListingProvider);
      state = state.copyWith(
        status: canStillAddCard
            ? PaymentMethodsStatus.listingUnavailable
            : PaymentMethodsStatus.error,
        methods: const [],
        errorMessage: canStillAddCard
            ? 'No pudimos consultar tus tarjetas guardadas: el listado '
                  'necesita el backend autenticado de Fluir. Aún puedes '
                  'agregar una tarjeta nueva.'
            : error.message,
        isRecoverable: error.isRecoverable,
        clearBusy: true,
      );
    }
  }

  /// The default card leads; the rest keep the gateway order.
  static List<PaymentMethod> _sorted(List<PaymentMethod> methods) {
    final sorted = [...methods];
    sorted.sort((a, b) {
      if (a.isDefault == b.isDefault) return 0;
      return a.isDefault ? -1 : 1;
    });
    return List.unmodifiable(sorted);
  }
}
