import 'package:flutter/material.dart';

/// The look of the app, built for one specific situation: a shopkeeper
/// standing behind a counter, holding the phone in one hand, in daylight, with
/// a queue waiting.
///
/// That drives every choice here — large type, large tap targets, strong
/// contrast, and no decoration that costs legibility.
class AppTheme {
  AppTheme._();

  /// The one brand colour.
  static const Color accent = Color(0xFF0F766E);

  /// Credit given — money going out on trust.
  static const Color owedInk = Color(0xFFB42318);

  /// Payment received, and settled accounts.
  static const Color paidInk = Color(0xFF15803D);

  /// Nothing smaller than this is ever tapped.
  static const double tapTarget = 56;

  /// The record button is the one thing a floury thumb must never miss.
  static const double recordButtonHeight = 84;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      // A low-end phone used at arm's length in sunlight: every size the app
      // leans on is set here, a step above the Material default. Written out
      // style by style rather than scaled by a factor, so the result does not
      // depend on which typography the platform happens to supply.
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 17),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(tapTarget),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(tapTarget),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide.none,
        ),
        labelStyle: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 14,
        horizontalTitleGap: 14,
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// The colour a balance should be shown in.
  static Color balanceInk(int balance, ColorScheme scheme) {
    if (balance > 0) {
      return scheme.brightness == Brightness.dark
          ? const Color(0xFFFF8A80)
          : owedInk;
    }
    if (balance < 0) {
      return scheme.brightness == Brightness.dark
          ? const Color(0xFF7BDCA0)
          : paidInk;
    }
    return scheme.onSurfaceVariant;
  }
}
