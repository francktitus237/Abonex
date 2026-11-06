import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/formatters.dart';

/// Statut métier d'une échéance — règle produit du CDC :
/// vert = payé, orange = bientôt dû, rouge = en retard.
enum SubscriptionStatus { paid, dueSoon, overdue }

enum BillingCycle { monthly, quarterly, yearly, daily, weekly, once }

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

  /// Clé de traduction — `context.tr(category.labelKey)`.
  String get labelKey => 'category.$name';

  /// Libellé dans la langue courante (via AppFormatters.lang).
  String get label => AppStrings.t(AppFormatters.lang, labelKey);

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
    this.country = '',
    this.countryFlag = '',
    this.startDate,
    this.endDate,
    this.dueTime,
    this.isShared = false,
    this.paymentUrl = '',
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

  /// Pays où l'abonnement est actif (ISO alpha-2) + drapeau —
  /// choisi par l'utilisateur au formulaire ; à défaut le pays
  /// du workspace.
  final String country;
  final String countryFlag;

  /// Date de souscription/première échéance — null si inconnue.
  final DateTime? startDate;

  /// Fin de contrat — null = renouvellement sans fin.
  final DateTime? endDate;

  /// Heure de l'échéance — renseignée pour les rendez-vous.
  final TimeOfDay? dueTime;

  /// Abonnement du foyer : charge partagée par la famille
  /// (CDC — abonnements « household » côté particuliers).
  final bool isShared;

  /// Lien de paiement direct (portail client/page marchande) —
  /// bouton « Payer » sur le détail.
  final String paymentUrl;

  /// Rendez-vous / événement — uniquement la catégorie dédiée.
  /// Un abonnement ponctuel (facture « une seule fois ») reste un
  /// abonnement : il se « paie », il ne « se termine » pas.
  bool get isEvent => category == SubscriptionCategory.event;

  /// Date + heure complètes de l'échéance (heure à minuit si absente).
  DateTime get dueAt => DateTime(
    nextDueDate.year,
    nextDueDate.month,
    nextDueDate.day,
    dueTime?.hour ?? 0,
    dueTime?.minute ?? 0,
  );

  String get cycleLabel =>
      AppStrings.t(AppFormatters.lang, 'cycle.${cycle.name}');

  /// "par mois" / "per month" — sous-titre du montant au détail.
  String get cyclePeriod =>
      AppStrings.t(AppFormatters.lang, 'cycle.per$_cycleKey');

  String get _cycleKey => switch (cycle) {
    BillingCycle.monthly => 'Monthly',
    BillingCycle.quarterly => 'Quarterly',
    BillingCycle.yearly => 'Yearly',
    BillingCycle.daily => 'Daily',
    BillingCycle.weekly => 'Weekly',
    BillingCycle.once => 'Once',
  };
}
