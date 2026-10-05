import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/authentication/presentation/controllers/customer_session_controller.dart';
import 'router/app_router.dart';
import 'system_ui.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class FluirApp extends ConsumerWidget {
  const FluirApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // An expired session sends the customer back to sign in. The ride (and
    // its trip id) is kept and reconciled after the next sign-in.
    ref.listen(customerSessionProvider.select((session) => session.status), (
      previous,
      next,
    ) {
      if (next == CustomerSessionStatus.expired && previous != next) {
        appRouter.go(AppRoutes.onboarding);
      }
    });
    final themeMode = ref.watch(themeControllerProvider);
    final isDark = themeMode == ThemeMode.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? AppSystemUi.lightContent : AppSystemUi.darkContent,
      child: MaterialApp.router(
        title: 'Fluir',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: appRouter,
      ),
    );
  }
}
