import '../models/card_entry.dart';
import '../models/payment_method.dart';

/// Turns a card the customer typed in the app into a saved payment method.
///
/// The contract is deliberately one-shot: an implementation receives the card,
/// hands it to whoever is allowed to hold it, and answers with the tokenised
/// method. Nothing about [CardEntry] may be stored, cached or logged on the way
/// through — the app only ever keeps the brand, the last four digits and the
/// expiry that come back.
abstract interface class CardVaultRepository {
  Future<PaymentMethod> saveCard(CardEntry card, {bool makeDefault = false});
}
