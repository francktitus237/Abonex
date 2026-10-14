import 'package:flutter/material.dart';

/// Palette officielle Abonex — dérivée du logo :
/// navy profond (fond du logo) + vert émeraude (le check).
/// Toutes les couleurs de l'app DOIVENT venir d'ici :
/// si la charte change un jour, on ne touche que ce fichier.
abstract final class AppColors {
  // ---------- Couleurs de marque (logo) ----------
  static const navy = Color(0xFF0B1F44); // navy profond du logo
  static const emerald = Color(0xFF10B981); // check émeraude du logo

  // ---------- Thème clair ----------
  static const lightPrimary = Color(0xFF0B9B6C); // émeraude lisible sur blanc
  static const lightBackground = Color(0xFFF6F8FB); // fond de page
  static const lightCard = Color(0xFFFFFFFF); // fond des cartes
  static const lightSuccess = Color(0xFF10B981); // vert = payé
  static const lightWarning = Color(0xFFF59E0B); // orange = bientôt dû
  static const lightDanger = Color(0xFFEF4444); // rouge = en retard

  // ---------- Thème sombre (neutre charbon + émeraude douce) ----------
  // Volontairement peu saturé : le navy pur donnait un rendu
  // "tout bleu" trop frappant — on reste sur du charbon neutre.
  static const darkPrimary = Color(0xFF3BBF92);
  static const darkBackground = Color(0xFF0D1114); // charbon neutre
  static const darkCard = Color(0xFF171D21); // carte charbon
  static const darkSuccess = Color(0xFF34D399);
  static const darkWarning = Color(0xFFE8B44A);
  static const darkDanger = Color(0xFFF87171);
}

/// Couleurs de statut résolues selon le thème actif.
///
/// C'est une règle produit, pas un détail cosmétique :
/// vert = payé, orange = bientôt dû, rouge = en retard.
/// Usage : `context.status.paid`, `context.status.overdue`…
class StatusColors {
  const StatusColors({
    required this.paid,
    required this.dueSoon,
    required this.overdue,
  });

  final Color paid;
  final Color dueSoon;
  final Color overdue;
}

extension StatusColorsX on BuildContext {
  StatusColors get status => Theme.of(this).brightness == Brightness.dark
      ? const StatusColors(
          paid: AppColors.darkSuccess,
          dueSoon: AppColors.darkWarning,
          overdue: AppColors.darkDanger,
        )
      : const StatusColors(
          paid: AppColors.lightSuccess,
          dueSoon: AppColors.lightWarning,
          overdue: AppColors.lightDanger,
        );
}
