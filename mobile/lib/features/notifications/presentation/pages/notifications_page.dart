import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../subscriptions/domain/entities/subscription.dart';
import '../../../subscriptions/presentation/cubit/subscriptions_cubit.dart';

/// Centre de notifications in-app : échéances en retard,
/// paiements à venir et rappels de mise à jour — construit
/// depuis le SubscriptionsCubit partagé.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.notifications'))),
      body: BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
        builder: (context, state) {
          if (state is! SubscriptionsLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final overdue =
              state.items
                  .where((s) => s.status == SubscriptionStatus.overdue)
                  .toList()
                ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
          final dueSoon =
              state.items
                  .where((s) => s.status == SubscriptionStatus.dueSoon)
                  .toList()
                ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

          if (overdue.isEmpty && dueSoon.isEmpty) {
            return EmptyState(
              icon: LucideIcons.bellOff,
              title: context.tr('notif.empty'),
              subtitle: context.tr('notif.emptySub'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              if (overdue.isNotEmpty) ...[
                _SectionHeader(
                  icon: LucideIcons.circleAlert,
                  title: context.tr('status.overdue'),
                  color: context.status.overdue,
                ),
                const SizedBox(height: 10),
                for (final s in overdue)
                  _NotificationTile(
                    subscription: s,
                    title: context.tr(
                      s.isEvent ? 'notif.pastEvent' : 'notif.duePassed',
                    ),
                    body: s.isEvent
                        ? (s.dueTime != null
                              ? AppFormatters.dateTimeLong(s.dueAt)
                              : AppFormatters.dateLong(s.nextDueDate))
                        : context.tr('notif.expected', {
                            'amount': AppFormatters.money(s.amount, s.currency),
                            'date': AppFormatters.dateLong(s.nextDueDate),
                          }),
                    color: context.status.overdue,
                    icon: LucideIcons.circleAlert,
                  ),
                const SizedBox(height: 20),
              ],
              if (dueSoon.isNotEmpty) ...[
                _SectionHeader(
                  icon: LucideIcons.clock,
                  title: context.tr('status.dueSoon'),
                  color: context.status.dueSoon,
                ),
                const SizedBox(height: 10),
                for (final s in dueSoon)
                  _NotificationTile(
                    subscription: s,
                    title: _dueIn(context, s),
                    body: s.isEvent
                        ? (s.dueTime != null
                              ? AppFormatters.dateTimeLong(s.dueAt)
                              : AppFormatters.dateLong(s.nextDueDate))
                        : '${AppFormatters.money(s.amount, s.currency)}'
                              '${s.provider.isEmpty ? '' : ' — ${s.provider}'}',
                    color: context.status.dueSoon,
                    icon: LucideIcons.bellRing,
                  ),
                const SizedBox(height: 20),
              ],
              // Rappel permanent : tenir la liste à jour.
              const _UpdateReminderCard(),
            ],
          );
        },
      ),
    );
  }

  static String _dueIn(BuildContext context, Subscription s) {
    final days = s.nextDueDate.difference(DateTime.now()).inDays;
    if (days <= 0) return context.tr('notif.dueToday');
    return context.tr('notif.dueIn', {'n': '$days'});
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.subscription,
    required this.title,
    required this.body,
    required this.color,
    required this.icon,
  });

  final Subscription subscription;
  final String title;
  final String body;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius - 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius - 4),
          onTap: () => context.push('/subscriptions/${subscription.id}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius - 4),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$title — ${subscription.name}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (subscription.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subscription.description,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateReminderCard extends StatelessWidget {
  const _UpdateReminderCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radius - 4),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.bellPlus, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('notif.hint'),
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.go('/subscriptions'),
            child: Text(context.tr('common.add')),
          ),
        ],
      ),
    );
  }
}
