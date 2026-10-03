import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/fluir_wordmark.dart';

/// The animated brand moment: the Fluir wordmark settling onto its plate over a
/// green stroke that flows out from the centre.
///
/// Takes a single [progress] value (0…1) so the screen owns the timeline and
/// the widget stays trivially testable at any frame.
class FluirFlowMark extends StatelessWidget {
  const FluirFlowMark({required this.progress, this.width = 220, super.key});

  final double progress;

  /// Optical width the wordmark and the flow stroke are laid out against.
  final double width;

  static const _markInterval = Interval(0, .48, curve: Curves.easeOutCubic);
  static const _flowInterval = Interval(.22, .78, curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final mark = _markInterval.transform(progress.clamp(0, 1).toDouble());
    final flow = _flowInterval.transform(progress.clamp(0, 1).toDouble());
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: mark,
          child: Transform.scale(
            scale: .9 + .1 * mark,
            child: FluirWordmark(
              color: AppColors.logoWordmark,
              fontSize: width * .42,
            ),
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 4,
          width: width,
          child: Align(
            alignment: Alignment.center,
            child: FractionallySizedBox(
              widthFactor: flow,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.logoWordmark.withValues(alpha: .85),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
