import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Construit les deux thèmes Material 3 de l'app.
/// Style visé : fintech sobre (Revolut, Linear) — beaucoup d'espace,
/// coins arrondis de 16 px, ombres très douces.
abstract final class AppTheme {
  /// Rayon d'angle unique du design system (cartes, boutons, champs…).
  static const double radius = 16;

  /// Ombre douce standard pour élever légèrement une carte.
  /// Règle : on n'utilise JAMAIS l'elevation Material brute sur les cartes.
  static List<BoxShadow> softShadow(Brightness brightness) => [
    BoxShadow(
      color: Colors.black.withValues(
        alpha: brightness == Brightness.dark ? 0.35 : 0.05,
      ),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static ThemeData light() => _build(
    brightness: Brightness.light,
    primary: AppColors.lightPrimary,
    scaffold: AppColors.lightBackground,
    card: AppColors.lightCard,
    danger: AppColors.lightDanger,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    primary: AppColors.darkPrimary,
    scaffold: AppColors.darkBackground,
    card: AppColors.darkCard,
    danger: AppColors.darkDanger,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color scaffold,
    required Color card,
    required Color danger,
  }) {
    // fromSeed génère les ~30 teintes Material 3 cohérentes entre elles ;
    // copyWith impose ensuite nos couleurs exactes du cahier des charges.
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      secondary: AppColors.emerald,
      surface: card,
      error: danger,
    );

    // Inter via google_fonts : aucun asset à déclarer, la police est
    // téléchargée et mise en cache au premier lancement.
    // Tracking négatif sur les titres : la signature visuelle des
    // apps fintech modernes (Linear, Revolut, Ramp).
    final base = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );
    final textTheme = base.copyWith(
      displayLarge: base.displayLarge
          ?.copyWith(letterSpacing: -1.6, fontWeight: FontWeight.w800),
      displayMedium: base.displayMedium
          ?.copyWith(letterSpacing: -1.1, fontWeight: FontWeight.w800),
      displaySmall: base.displaySmall
          ?.copyWith(letterSpacing: -0.8, fontWeight: FontWeight.w800),
      headlineLarge: base.headlineLarge
          ?.copyWith(letterSpacing: -0.8, fontWeight: FontWeight.w800),
      headlineMedium: base.headlineMedium
          ?.copyWith(letterSpacing: -0.6, fontWeight: FontWeight.w800),
      headlineSmall: base.headlineSmall
          ?.copyWith(letterSpacing: -0.4, fontWeight: FontWeight.w800),
      titleLarge: base.titleLarge
          ?.copyWith(letterSpacing: -0.3, fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium
          ?.copyWith(letterSpacing: -0.2, fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffold,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        // Sans ça, Material 3 teinte la barre en violet au scroll.
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),

      cardTheme: CardThemeData(
        color: card,
        elevation: 0, // l'élévation visuelle vient de softShadow, pas de M3
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          // Bordure très légère : les cartes restent nettes
          // même sans ombre (utile en mode clair).
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 4),
        ),
      ),

      // Bottom sheets : coins hauts très arrondis + poignée de drag —
      // le standard des apps modernes.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(card),
          surfaceTintColor: const WidgetStatePropertyAll(
            Colors.transparent,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.labelSmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          scheme.outline.withValues(alpha: 0.6),
        ),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(4),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 52),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: _inputBorder(scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.primary, width: 1.6),
        errorBorder: _inputBorder(scheme.error),
      ),

      // NavigationBar = barre du bas Material 3
      // (Accueil · Abonnements · Calendrier · Rapports · Profil).
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );
}
