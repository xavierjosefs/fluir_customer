import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/card_entry.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/payment_vault_exception.dart';
import '../payments_providers.dart';

/// Where the customer is while registering a card in the app.
enum AddCardStage {
  editing,

  /// The card is being tokenised. The form stays on screen but locked.
  tokenizing,

  /// The vault confirmed the card and it is saved.
  saved,

  /// The attempt failed. The form is editable again and explains why.
  failed,
}

@immutable
class AddCardState {
  const AddCardState({
    this.draft = const CardEntryDraft(),
    this.errors = const {},
    this.stage = AddCardStage.editing,
    this.makeDefault = true,
    this.message,
    this.isRecoverable = true,
    this.savedMethod,
  });

  final CardEntryDraft draft;

  /// Field-level problems. Only populated after a submit attempt, so the form
  /// does not shout at the customer while they are still typing.
  final Map<CardField, String> errors;
  final AddCardStage stage;
  final bool makeDefault;

  /// Form-level problem, such as a declined card or a transport failure.
  final String? message;
  final bool isRecoverable;
  final PaymentMethod? savedMethod;

  bool get isBusy => stage == AddCardStage.tokenizing;

  /// The submit button stays enabled until the card is actually saved, so the
  /// customer can correct a field and try again without leaving the screen.
  bool get canSubmit => !isBusy && stage != AddCardStage.saved;

  AddCardState copyWith({
    CardEntryDraft? draft,
    Map<CardField, String>? errors,
    AddCardStage? stage,
    bool? makeDefault,
    String? message,
    bool? isRecoverable,
    PaymentMethod? savedMethod,
    bool clearMessage = false,
  }) => AddCardState(
    draft: draft ?? this.draft,
    errors: errors ?? this.errors,
    stage: stage ?? this.stage,
    makeDefault: makeDefault ?? this.makeDefault,
    message: clearMessage ? null : message ?? this.message,
    isRecoverable: isRecoverable ?? this.isRecoverable,
    savedMethod: savedMethod ?? this.savedMethod,
  );
}

/// Drives the in-app card form: validate on the device, hand the card to the
/// vault once, and report only what the vault actually confirmed.
///
/// The card itself never leaves [AddCardState.draft], which is discarded as
/// soon as the screen closes. Nothing here logs, persists or re-sends it.
class AddCardController extends Notifier<AddCardState> {
  @override
  AddCardState build() => const AddCardState();

  void updateNumber(String value) =>
      _edit(state.draft.copyWith(number: value), CardField.number);

  void updateExpiry(String value) =>
      _edit(state.draft.copyWith(expiry: value), CardField.expiry);

  void updateSecurityCode(String value) =>
      _edit(state.draft.copyWith(securityCode: value), CardField.securityCode);

  void updateHolder(String value) =>
      _edit(state.draft.copyWith(holder: value), CardField.holder);

  void setMakeDefault(bool value) => state = state.copyWith(makeDefault: value);

  void reset() => state = const AddCardState();

  Future<void> submit() async {
    if (!state.canSubmit) return;

    final errors = state.draft.validate();
    if (errors.isNotEmpty) {
      state = state.copyWith(
        errors: errors,
        stage: AddCardStage.editing,
        clearMessage: true,
      );
      return;
    }
    final card = state.draft.toEntry();
    if (card == null) return;

    state = state.copyWith(
      stage: AddCardStage.tokenizing,
      errors: const {},
      clearMessage: true,
    );

    try {
      final saved = await ref
          .read(cardVaultRepositoryProvider)
          .saveCard(card, makeDefault: state.makeDefault);
      if (!ref.mounted) return;
      // The wallet is re-read from the vault: the screen never shows a card the
      // vault did not confirm.
      await ref.read(paymentMethodsControllerProvider.notifier).refresh();
      if (!ref.mounted) return;
      state = state.copyWith(
        stage: AddCardStage.saved,
        savedMethod: saved,
        // Nothing keeps the typed card alive once it has been vaulted.
        draft: const CardEntryDraft(),
        message: 'Tu ${saved.displayBrand} quedó lista para usarse.',
      );
    } on PaymentVaultException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        stage: AddCardStage.failed,
        message: error.message,
        isRecoverable: error.isRecoverable,
      );
    }
  }

  /// Applies an edit and clears that field's error, so a correction is
  /// acknowledged immediately.
  void _edit(CardEntryDraft draft, CardField field) {
    final errors = state.errors.containsKey(field)
        ? (Map.of(state.errors)..remove(field))
        : state.errors;
    state = state.copyWith(
      draft: draft,
      errors: errors,
      stage: state.stage == AddCardStage.failed
          ? AddCardStage.editing
          : state.stage,
    );
  }
}
