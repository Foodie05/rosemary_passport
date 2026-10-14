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
  final subtle = dark
      ? RosmEpassDarkTokens.surfaceSubtle
      : RosmEpassLightTokens.surfaceSubtle;
  final ink = dark ? RosmEpassDarkTokens.text : RosmEpassLightTokens.text;
  final muted = dark
      ? RosmEpassDarkTokens.textSecondary
      : RosmEpassLightTokens.textSecondary;
  final border = dark
      ? RosmEpassDarkTokens.border
      : RosmEpassLightTokens.border;
  final control = dark
      ? RosmEpassDarkTokens.borderControl
      : RosmEpassLightTokens.borderControl;
  final scheme =
      ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
        primary: primary,
        onPrimary: dark
            ? RosmEpassDarkTokens.onAccent
            : RosmEpassLightTokens.onAccent,
        primaryContainer: dark
            ? RosmEpassDarkTokens.accentSubtle
            : RosmEpassLightTokens.accentSubtle,
        onPrimaryContainer: ink,
        secondary: primary,
        onSecondary: dark
            ? RosmEpassDarkTokens.onAccent
            : RosmEpassLightTokens.onAccent,
        secondaryContainer: dark
            ? RosmEpassDarkTokens.accentSubtle
            : RosmEpassLightTokens.accentSubtle,
        onSecondaryContainer: primary,
        tertiary: dark
            ? RosmEpassDarkTokens.warning
            : RosmEpassLightTokens.warning,
        tertiaryContainer: dark
            ? RosmEpassDarkTokens.warningSubtle
            : RosmEpassLightTokens.warningSubtle,
        onTertiaryContainer: dark
            ? RosmEpassDarkTokens.warning
            : RosmEpassLightTokens.warning,
        surface: canvas,
        surfaceContainerLowest: surface,
        surfaceContainerLow: surface,
        surfaceContainer: subtle,
        surfaceContainerHigh: subtle,
        surfaceContainerHighest: subtle,
        onSurface: ink,
        onSurfaceVariant: muted,
        outline: control,
        outlineVariant: border,
        error: dark ? RosmEpassDarkTokens.danger : RosmEpassLightTokens.danger,
        errorContainer: dark
            ? RosmEpassDarkTokens.dangerSubtle
            : RosmEpassLightTokens.dangerSubtle,
        onErrorContainer: dark
            ? RosmEpassDarkTokens.danger
            : RosmEpassLightTokens.danger,
      );
  final inherited = Theme.of(context);
  final duration = MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : RosmEpassMotion.hover;
  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(RosmEpassGeometry.control),
        borderSide: BorderSide(color: color, width: width),
      );
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
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w500),
      floatingLabelStyle: TextStyle(color: primary),
      prefixIconColor: muted,
      enabledBorder: outline(control),
      focusedBorder: outline(primary, 2),
      errorBorder: outline(scheme.error),
      focusedErrorBorder: outline(scheme.error, 2),
      disabledBorder: outline(border),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: control),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RosmEpassGeometry.control),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        elevation: 0,
      ).copyWith(animationDuration: duration),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        backgroundColor: surface,
        side: BorderSide(color: control),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RosmEpassGeometry.control),
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
      colors: data.brightness == Brightness.dark
          ? RosmEpassDarkTokens.colors
          : RosmEpassLightTokens.colors,
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
