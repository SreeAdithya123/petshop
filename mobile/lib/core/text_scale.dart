import 'package:flutter/widgets.dart';

/// Bounds for the user's system font scaling. Below 0.85 text becomes hard to
/// read; above 1.3 the fixed-height layouts (chips, cards, app bars) break.
const double kMinTextScale = 0.85;
const double kMaxTextScale = 1.3;

/// `MaterialApp.builder` that clamps the system text scale to
/// [kMinTextScale]..[kMaxTextScale] while still honouring accessibility
/// settings inside that range.
Widget clampTextScale(BuildContext context, Widget? child) {
  final media = MediaQuery.of(context);
  return MediaQuery(
    data: media.copyWith(
      textScaler: media.textScaler.clamp(minScaleFactor: kMinTextScale, maxScaleFactor: kMaxTextScale),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}
