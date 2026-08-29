import 'package:go_router/go_router.dart';

import '../../features/account/presentation/screens/account_placeholder_screen.dart';
import '../../features/activity/presentation/screens/activity_screen.dart';
import '../../features/authentication/presentation/screens/auth_success_screen.dart';
import '../../features/authentication/presentation/screens/code_sent_screen.dart';
import '../../features/authentication/presentation/screens/otp_screen.dart';
import '../../features/authentication/presentation/screens/phone_number_screen.dart';
import '../../features/authentication/presentation/widgets/auth_flow_coordinator.dart';
import '../../features/home/presentation/screens/destination_search_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/payments/presentation/screens/payments_placeholder_screen.dart';
import 'app_shell.dart';

abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const home = '/inicio';
  static const destinationSearch = '/buscar-destino';
  static const activity = '/actividad';
  static const payments = '/pagos';
  static const account = '/cuenta';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.onboarding,
  routes: [
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AuthFlowCoordinator(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.auth,
          redirect: (context, state) => AppRoutes.onboarding,
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
    GoRoute(
      path: AppRoutes.destinationSearch,
      builder: (context, state) => const DestinationSearchScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          FluirAppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.activity,
              builder: (context, state) => const ActivityScreen(),
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
    GoRoute(
      path: AppRoutes.payments,
      builder: (context, state) => const PaymentsPlaceholderScreen(),
    ),
  ],
);
