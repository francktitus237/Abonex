import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/subscription.dart';

/// Ligne d'abonnement réutilisable : icône de catégorie, nom,
/// date relative, montant + badge de statut.
class SubscriptionTile extends StatelessWidget {
  const SubscriptionTile({
    super.key,
    required this.subscription,
    this.onMarkPaid,
    this.onTap,
  });

  final Subscription subscription;

  /// Tap sur la carte → ouvre la fiche détail.
  final VoidCallback? onTap;

  /// Si fourni et que l'échéance n'est pas payée, affiche un
  /// bouton "marquer payé" — PATCH /subscriptions/ID/.
  final VoidCallback? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sub = subscription;

    final (statusColor, statusLabel) = switch (sub.status) {
      SubscriptionStatus.paid => (context.status.paid, 'Payé'),
      SubscriptionStatus.dueSoon => (
        context.status.dueSoon,
        AppFormatters.relativeDay(sub.nextDueDate),
      ),
      SubscriptionStatus.overdue => (
        context.status.overdue,
        AppFormatters.relativeDay(sub.nextDueDate),
      ),
    };

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: sub.category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(sub.category.icon, size: 20, color: sub.category.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${sub.cycleLabel} · ${AppFormatters.dateShort(sub.nextDueDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.money(sub.amount, sub.currency),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onMarkPaid != null &&
                      sub.status != SubscriptionStatus.paid)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: InkWell(
                        onTap: onMarkPaid,
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: context.status.paid.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.check,
                            size: 14,
                            color: context.status.paid,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }
}
