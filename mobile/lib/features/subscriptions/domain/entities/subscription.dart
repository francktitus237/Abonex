import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Statut métier d'une échéance — règle produit du CDC :
/// vert = payé, orange = bientôt dû, rouge = en retard.
enum SubscriptionStatus { paid, dueSoon, overdue }

enum BillingCycle { monthly, quarterly, yearly, once }

/// Catégories d'abonnements (loyers, logiciels, assurances…).
enum SubscriptionCategory {
  software,
  rent,
  insurance,
  telecom,
  energy,
  water,
  payroll,
  transport,
  event,
  other;

  String get label => switch (this) {
    software => 'Logiciels',
    rent => 'Loyers',
    insurance => 'Assurances',
    telecom => 'Télécom',
    energy => 'Énergie',
    water => 'Eau',
    payroll => 'Salaires',
    transport => 'Transport',
    event => 'Événement',
    other => 'Autre',
  };

  IconData get icon => switch (this) {
    software => LucideIcons.cloud,
    rent => LucideIcons.building2,
    insurance => LucideIcons.shieldCheck,
    telecom => LucideIcons.smartphone,
    energy => LucideIcons.zap,
    water => LucideIcons.droplets,
    payroll => LucideIcons.users,
    transport => LucideIcons.truck,
    event => LucideIcons.calendarClock,
    other => LucideIcons.tag,
  };

  Color get color => switch (this) {
    software => const Color(0xFF6366F1),
    rent => const Color(0xFF8B5CF6),
    insurance => const Color(0xFF0EA5E9),
    telecom => const Color(0xFFF59E0B),
    energy => const Color(0xFF10B981),
    water => const Color(0xFF38BDF8),
    payroll => const Color(0xFF14B8A6),
    transport => const Color(0xFFEC4899),
    event => const Color(0xFFF97316),
    other => const Color(0xFF64748B),
  };

  static SubscriptionCategory parse(String value) =>
      SubscriptionCategory.values.firstWhere(
        (c) => c.name == value,
        orElse: () => SubscriptionCategory.other,
      );
}

/// Abonnement / échéance récurrente — entité du domaine.
class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.provider,
    required this.category,
    required this.amount,
    required this.nextDueDate,
    required this.cycle,
    required this.status,
    this.currency = 'XAF',
    this.description = '',
    this.startDate,
    this.endDate,
    this.dueTime,
  });

  final String id;
  final String name;
  final String provider;
  final SubscriptionCategory category;
  final double amount;
  final DateTime nextDueDate;
  final BillingCycle cycle;
  final SubscriptionStatus status;
  final String currency;

  /// Note libre : ville/lieu du service, référence du contrat…
  /// Rappelée dans les alertes et notifications.
  final String description;

  /// Date de souscription/première échéance — null si inconnue.
  final DateTime? startDate;

  /// Fin de contrat — null = renouvellement sans fin.
  final DateTime? endDate;

  /// Heure de l'échéance — renseignée pour les rendez-vous.
  final TimeOfDay? dueTime;

  /// Rendez-vous / événement ponctuel (pas un abonnement facturé).
  bool get isEvent =>
      category == SubscriptionCategory.event || cycle == BillingCycle.once;

  /// Date + heure complètes de l'échéance (heure à minuit si absente).
  DateTime get dueAt => DateTime(
    nextDueDate.year,
    nextDueDate.month,
    nextDueDate.day,
    dueTime?.hour ?? 0,
    dueTime?.minute ?? 0,
  );

  String get cycleLabel => switch (cycle) {
    BillingCycle.monthly => 'Mensuel',
    BillingCycle.quarterly => 'Trimestriel',
    BillingCycle.yearly => 'Annuel',
    BillingCycle.once => 'Une seule fois',
  };
}
