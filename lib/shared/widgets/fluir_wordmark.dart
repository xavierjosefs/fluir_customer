import 'package:flutter/material.dart';

/// The official standalone Fluir wordmark.
///
/// The asset is a single-colour matte of the real letterforms, so the approved
/// contextual variants (white on Fluir blue, green on Fluir blue, dark on a
/// light surface) are produced by tinting it — never by redrawing the mark with
/// an unrelated typeface.
class FluirWordmark extends StatelessWidget {
  const FluirWordmark({this.color = Colors.white, this.fontSize, super.key});

  static const asset = 'assets/brand/fluir_wordmark.png';

  /// The artwork is tighter than a text line box, so the requested [fontSize]
  /// is scaled down to keep the optical size callers expect.
  static const _opticalScale = .78;
  static const _defaultFontSize = 32.0;

  final Color color;

  /// Optical size of the wordmark, expressed the way a font size would be.
  final double? fontSize;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Fluir',
    image: true,
    child: Image.asset(
      asset,
      height: (fontSize ?? _defaultFontSize) * _opticalScale,
      color: color,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}
