import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/system_ui.dart';
import '../../../../app/theme/app_colors.dart';
import '../widgets/fluir_flow_mark.dart';

/// Brand entry point: the Fluir plate with its wordmark animating in before the
/// app hands over to onboarding.
///
/// The splash is a brand moment, so it is deliberately theme-independent and
/// always reproduces the official plate colours. It never becomes a dead end:
/// the hand-off runs even if the animation is skipped or cut short.
class SplashScreen extends StatefulWidget {
  const SplashScreen({this.onCompleted, super.key});

  static const duration = Duration(milliseconds: 2100);

  /// Shortened hold used when the platform asks for reduced motion.
  static const reducedMotionDuration = Duration(milliseconds: 700);

  /// Test seam. Defaults to continuing into onboarding.
  final VoidCallback? onCompleted;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SplashScreen.duration,
  );
  bool _handedOver = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduced motion still gets the brand moment, just without the movement.
      _controller.value = 1;
      Future<void>.delayed(SplashScreen.reducedMotionDuration, _complete);
      return;
    }
    _controller.forward().whenComplete(_complete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _complete() {
    if (_handedOver || !mounted) return;
    _handedOver = true;
    final onCompleted = widget.onCompleted;
    if (onCompleted != null) {
      onCompleted();
      return;
    }
    context.go(AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: AppSystemUi.lightContent,
    child: Scaffold(
      backgroundColor: AppColors.logoPlate,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth * .56).clamp(180.0, 280.0);
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Stack(
              fit: StackFit.expand,
              children: [
                _Glow(progress: _controller.value),
                Center(
                  child: FluirFlowMark(
                    progress: _controller.value,
                    width: width,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// Soft halo behind the wordmark. Keeps the plate from reading as flat without
/// resorting to a heavy gradient.
class _Glow extends StatelessWidget {
  const _Glow({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final bloom = Curves.easeOutCubic.transform(
      progress.clamp(0, 1).toDouble(),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: .45 + .55 * bloom,
          colors: [
            AppColors.logoWordmark.withValues(alpha: .16 * bloom),
            AppColors.logoPlate.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
