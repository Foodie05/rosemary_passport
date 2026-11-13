import 'package:flutter/material.dart';
import 'package:rosemary_ui/rosemary_ui.dart';

import 'epass_tokens.dart';
import 'models.dart';

Brightness resolveRosmPassportBrightness(
  BuildContext context,
  RosmPassportThemeMode mode,
) => switch (mode) {
  RosmPassportThemeMode.system => MediaQuery.platformBrightnessOf(context),
  RosmPassportThemeMode.light => Brightness.light,
  RosmPassportThemeMode.dark => Brightness.dark,
};

ThemeData buildRosmPassportTheme(
  BuildContext context,
  RosmPassportThemeMode mode,
) {
  final brightness = resolveRosmPassportBrightness(context, mode);
  final dark = brightness == Brightness.dark;
  final primary = dark
      ? RosmEpassDarkTokens.accent
      : RosmEpassLightTokens.accent;
  final canvas = dark
      ? RosmEpassDarkTokens.canvas
      : RosmEpassLightTokens.canvas;
  final surface = dark
      ? RosmEpassDarkTokens.surface
      : RosmEpassLightTokens.surface;
  final ink = dark ? RosmEpassDarkTokens.text : RosmEpassLightTokens.text;
  final muted = dark
      ? RosmEpassDarkTokens.textSecondary
      : RosmEpassLightTokens.textSecondary;
  final control = dark
      ? RosmEpassDarkTokens.borderControl
      : RosmEpassLightTokens.borderControl;
  final c = dark ? RosmEpassDarkTokens.colors : RosmEpassLightTokens.colors;
  // Consume the canonical paired recipe; do not regenerate HCT on each platform.
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primarySoft,
    onPrimaryContainer: c.ink,
    secondary: c.primary,
    onSecondary: c.onPrimary,
    secondaryContainer: c.secondaryContainer,
    onSecondaryContainer: c.onSecondaryContainer,
    tertiary: c.onTertiaryContainer,
    onTertiary: c.tertiaryContainer,
    tertiaryContainer: c.tertiaryContainer,
    onTertiaryContainer: c.onTertiaryContainer,
    surface: c.surfaceGroup,
    onSurface: c.ink,
    onSurfaceVariant: c.muted,
    surfaceContainerLowest: c.surface,
    surfaceContainerLow: c.surfaceGroup,
    surfaceContainer: c.surfaceInset,
    surfaceContainerHigh: c.surfaceFloating,
    surfaceContainerHighest: c.surfaceFloating,
    outline: c.control,
    outlineVariant: c.edgeSoft,
    error: c.danger,
    onError: c.onDanger,
    errorContainer: c.dangerSoft,
    onErrorContainer: c.danger,
    inverseSurface: dark
        ? RosmEpassLightTokens.colors.surfaceGroup
        : RosmEpassDarkTokens.colors.surfaceGroup,
    onInverseSurface: dark
        ? RosmEpassLightTokens.colors.ink
        : RosmEpassDarkTokens.colors.ink,
  );
  final inherited = Theme.of(context);
  final duration = MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : RosmEpassMotion.hover;
  final textTheme = inherited.textTheme.apply(
    bodyColor: ink,
    displayColor: ink,
  );
  return ThemeData(brightness: brightness).copyWith(
    extensions: [
      RosemaryThemeData(
        colors: dark ? RosmEpassDarkTokens.colors : RosmEpassLightTokens.colors,
      ),
    ],
    platform: inherited.platform,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: textTheme.copyWith(
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontFamily: null,
        fontFamilyFallback: const [],
        fontWeight: FontWeight.w400,
      ),
    ),
    scaffoldBackgroundColor: canvas,
    iconTheme: IconThemeData(size: 20, color: muted),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w500),
      floatingLabelStyle: TextStyle(color: primary),
      prefixIconColor: muted,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: control),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RosmEpassGeometry.control),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
      ).copyWith(animationDuration: duration),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        backgroundColor: surface,
        side: BorderSide(color: control),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RosmEpassGeometry.control),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ).copyWith(animationDuration: duration),
    ),
  );
}

/// Applies the Epass palette through the official Forma provider.
class RosmEpassTheme extends StatelessWidget {
  const RosmEpassTheme({super.key, required this.data, required this.child});
  final ThemeData data;
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
    data: data,
    child: RosemaryTheme(
      mode: data.brightness == Brightness.dark
          ? RosemaryThemeMode.dark
          : RosemaryThemeMode.light,
      scheme: const RosemaryColorScheme(
        light: RosmEpassLightTokens.colors,
        dark: RosmEpassDarkTokens.colors,
      ),
      highContrastColors:
          (data.brightness == Brightness.dark
                  ? RosmEpassDarkTokens.colors
                  : RosmEpassLightTokens.colors)
              .copyWith(
                control: data.colorScheme.onSurface,
                border: data.colorScheme.onSurfaceVariant,
              ),
      strings: rosemaryChinese,
      child: child,
    ),
  );
}
