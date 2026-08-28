import 'package:go_router/go_router.dart';

import '../../features/account/presentation/screens/account_placeholder_screen.dart';
import '../../features/activity/presentation/screens/activity_placeholder_screen.dart';
import '../../features/home/presentation/screens/home_placeholder_screen.dart';
import '../../features/payments/presentation/screens/payments_placeholder_screen.dart';
import 'app_shell.dart';

abstract final class AppRoutes {
  static const home = '/inicio';
  static const activity = '/actividad';
  static const payments = '/pagos';
  static const account = '/cuenta';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
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
