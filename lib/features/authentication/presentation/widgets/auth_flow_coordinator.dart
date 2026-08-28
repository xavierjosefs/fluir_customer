import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../../domain/models/auth_state.dart';

class AuthFlowCoordinator extends ConsumerWidget {
  const AuthFlowCoordinator({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authControllerProvider, (previous, next) {
      final destination = switch (next.status) {
        AuthStatus.entry => '/onboarding',
        AuthStatus.editingPhone => '/auth/phone',
        AuthStatus.sendingCode => '/auth/phone',
        AuthStatus.codeSent => '/auth/code-sent',
        AuthStatus.enteringOtp ||
        AuthStatus.verifyingOtp ||
        AuthStatus.invalidOtp ||
        AuthStatus.expiredOtp => '/auth/otp',
        AuthStatus.sendFailure => '/auth/phone',
        AuthStatus.verified => '/auth/success',
      };
      if (GoRouterState.of(context).uri.path != destination) {
        context.go(destination);
      }
    });
    return child;
  }
}
