import 'package:flutter/material.dart';

/// Temporary lowercase text fallback until the official standalone asset exists.
class FluirWordmark extends StatelessWidget {
  const FluirWordmark({this.color = Colors.white, this.fontSize, super.key});

  final Color color;
  final double? fontSize;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Fluir',
    child: Text(
      'fluir',
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
        color: color,
        fontSize: fontSize,
        letterSpacing: -1.2,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
