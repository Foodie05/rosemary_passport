import 'package:flutter/material.dart';

import 'models.dart';

const _seedColor = Color(0xFF5F7F63);

Brightness resolveRosmPassportBrightness(
  BuildContext context,
  RosmPassportThemeMode mode,
) {
  return switch (mode) {
    RosmPassportThemeMode.system => MediaQuery.platformBrightnessOf(context),
    RosmPassportThemeMode.light => Brightness.light,
    RosmPassportThemeMode.dark => Brightness.dark,
  };
}

ThemeData buildRosmPassportTheme(
  BuildContext context,
  RosmPassportThemeMode mode,
) {
  final brightness = resolveRosmPassportBrightness(context, mode);
  final scheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  );
  final inherited = Theme.of(context);
  final textTheme = inherited.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      labelStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
      floatingLabelStyle: TextStyle(
        color: scheme.primary,
        fontWeight: FontWeight.w700,
      ),
      prefixIconColor: scheme.onSurfaceVariant,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        elevation: 3,
        shadowColor: scheme.shadow.withAlpha(51),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outline),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}
