import 'package:flutter/foundation.dart';

/// Identity the gateway uses to scope payment methods (`companyId` +
/// `tenantReference`).
///
/// This value travels in URL paths, request bodies, gateway logs, access logs
/// and traces, so it must be an **opaque identifier**. It is never derived from
/// a phone number, email, document number or any other personal data.
///
/// The gateway currently trusts whatever the caller sends, so this is a routing
/// key, not an authorisation. In production the opaque id has to be issued by
/// the authenticated Fluir backend; see the module notes in
/// `docs/development`.
@immutable
class PaymentCustomerIdentity {
  const PaymentCustomerIdentity({
    required this.tenantReference,
    required this.userId,
    required this.isDebugFallback,
  });

  /// Single-customer demo identity, the only identity this build uses.
  ///
  /// Centralised here on purpose so no widget or service has to know about it.
  static const debugFallback = PaymentCustomerIdentity(
    tenantReference: debugFallbackReference,
    userId: debugFallbackReference,
    isDebugFallback: true,
  );

  static const debugFallbackReference = 'fluir-demo-customer-001';

  final String tenantReference;
  final String userId;
  final bool isDebugFallback;

  @override
  bool operator ==(Object other) =>
      other is PaymentCustomerIdentity &&
      other.tenantReference == tenantReference &&
      other.userId == userId &&
      other.isDebugFallback == isDebugFallback;

  @override
  int get hashCode => Object.hash(tenantReference, userId, isDebugFallback);

  @override
  String toString() => 'PaymentCustomerIdentity($tenantReference)';
}
