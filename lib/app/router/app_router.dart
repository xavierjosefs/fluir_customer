import 'package:go_router/go_router.dart';

import '../../features/account/presentation/screens/account_placeholder_screen.dart';
import '../../features/activity/presentation/screens/activity_placeholder_screen.dart';
import '../../features/authentication/presentation/screens/auth_entry_screen.dart';
import '../../features/authentication/presentation/screens/auth_success_screen.dart';
import '../../features/authentication/presentation/screens/code_sent_screen.dart';
import '../../features/authentication/presentation/screens/otp_screen.dart';
import '../../features/authentication/presentation/screens/phone_number_screen.dart';
import '../../features/authentication/presentation/widgets/auth_flow_coordinator.dart';
import '../../features/home/presentation/screens/home_placeholder_screen.dart';
import '../../features/payments/presentation/screens/payments_placeholder_screen.dart';
import 'app_shell.dart';

abstract final class AppRoutes {
  static const auth = '/auth';
  static const home = '/inicio';
  static const activity = '/actividad';
  static const payments = '/pagos';
  static const account = '/cuenta';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.auth,
  routes: [
    ShellRoute(
      builder: (context, state, child) => AuthFlowCoordinator(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.auth,
          builder: (context, state) => const AuthEntryScreen(),
        ),
        GoRoute(
          path: '${AppRoutes.auth}/phone',
          builder: (context, state) => const PhoneNumberScreen(),
        ),
        GoRoute(
          path: '${AppRoutes.auth}/code-sent',
          builder: (context, state) => const CodeSentScreen(),
        ),
        GoRoute(
          path: '${AppRoutes.auth}/otp',
          builder: (context, state) => const OtpScreen(),
        ),
        GoRoute(
          path: '${AppRoutes.auth}/success',
          builder: (context, state) => const AuthSuccessScreen(),
        ),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          FluirAppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomePlaceholderScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.activity,
              builder: (context, state) => const ActivityPlaceholderScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.payments,
              builder: (context, state) => const PaymentsPlaceholderScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.account,
              builder: (context, state) => const AccountPlaceholderScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
