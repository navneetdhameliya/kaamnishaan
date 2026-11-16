import 'package:flutter/material.dart';

import 'kn_tokens.g.dart';

/// Builds Material themes from the generated Figma tokens.
/// Screens read semantic colours through `context.kn` (see KnThemeExt).
abstract final class KnTheme {
  static ThemeData light(Locale locale) => _build(KnColors.light, Brightness.light, locale);
  static ThemeData dark(Locale locale) => _build(KnColors.dark, Brightness.dark, locale);

  static ThemeData _build(KnColors c, Brightness b, Locale locale) {
    final t = KnText.forLocale(locale);
    final scheme = ColorScheme(
      brightness: b,
      primary: c.actionPrimary,
      onPrimary: c.textOnAction,
      secondary: c.actionSecondary,
      onSecondary: c.textPrimary,
      error: c.statusDanger,
      onError: c.bgSurface,
      surface: c.bgSurface,
      onSurface: c.textPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bgCanvas,
      fontFamily: t.body.fontFamily,
      textTheme: TextTheme(
        displayLarge: t.display,
        headlineLarge: t.h1,
        headlineMedium: t.h2,
        titleLarge: t.h3,
        bodyLarge: t.bodyLg,
        bodyMedium: t.body,
        labelLarge: t.label,
        labelMedium: t.labelSm,
        bodySmall: t.caption,
        labelSmall: t.captionStrong,
      ).apply(bodyColor: c.textPrimary, displayColor: c.textPrimary),
      dividerColor: c.borderDefault,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(KnSize.tapTechnician),
          backgroundColor: c.actionPrimary,
          foregroundColor: c.textOnAction,
          textStyle: t.label,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KnSize.radiusLg)),
        ),
      ),
      extensions: [KnThemeExt(c)],
    );
  }
}

class KnThemeExt extends ThemeExtension<KnThemeExt> {
  const KnThemeExt(this.colors);
  final KnColors colors;
  @override
  KnThemeExt copyWith({KnColors? colors}) => KnThemeExt(colors ?? this.colors);
  @override
  KnThemeExt lerp(KnThemeExt? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension KnContext on BuildContext {
  KnColors get kn => Theme.of(this).extension<KnThemeExt>()!.colors;
}
