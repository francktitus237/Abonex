import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/countries.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/subscription.dart';
import '../cubit/subscriptions_cubit.dart';
import 'subscriptions_page.dart';

/// Détail d'un abonnement : fiche complète + actions
/// (marquer payé, supprimer). Les données sont relues depuis
/// le SubscriptionsCubit partagé — l'écran reste à jour après
/// chaque action.
class SubscriptionDetailPage extends StatelessWidget {
  const SubscriptionDetailPage({super.key, required this.subscriptionId});

  final String subscriptionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('detail.title'))),
      body: BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
        builder: (context, state) {
          final sub = context.read<SubscriptionsCubit>().byId(subscriptionId);
          if (sub == null) {
            if (state is SubscriptionsLoaded) {
              // Supprimé ou inexistant → retour propre à la liste.
              return EmptyState(
                icon: LucideIcons.searchX,
                title: context.tr('detail.notFound'),
                subtitle: context.tr('detail.notFoundSub'),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          return _DetailBody(subscription: sub);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sub = subscription;
    final statusColor = switch (sub.status) {
      SubscriptionStatus.paid => context.status.paid,
      SubscriptionStatus.dueSoon => context.status.dueSoon,
      SubscriptionStatus.overdue => context.status.overdue,
    };
    final statusLabel = switch (sub.status) {
      SubscriptionStatus.paid =>
        context.tr(sub.isEvent ? 'status.done' : 'status.paid'),
      SubscriptionStatus.dueSoon => context.tr('status.dueSoon'),
      SubscriptionStatus.overdue => context.tr('status.overdue'),
    };
    final days = sub.nextDueDate.difference(DateTime.now()).inDays;
    final countdown = sub.status == SubscriptionStatus.paid
        ? context.tr(sub.isEvent ? 'status.done' : 'status.settled')
        : days < 0
        ? context.tr('date.late', {'n': '${-days}'})
        : days == 0
        ? context.tr('date.today')
        : context.tr('date.in', {'n': '$days'});

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // --- En-tête : icône catégorie + nom + montant ---
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius + 4),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: sub.category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  sub.category.icon,
                  color: sub.category.color,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                sub.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (sub.provider.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  sub.provider,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (sub.isEvent) ...[
                Text(
                  AppFormatters.dateLong(sub.nextDueDate),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  sub.dueTime != null
                      ? context.tr('detail.at', {
                          'time': AppFormatters.time(
                            sub.dueTime!.hour,
                            sub.dueTime!.minute,
                          ),
                        })
                      : context.tr('event.label'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                Text(
                  AppFormatters.money(sub.amount, sub.currency),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  sub.cyclePeriod,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Informations ---
        _InfoCard(
          rows: sub.isEvent
              ? [
                  (
                    icon: LucideIcons.calendar,
                    label: context.tr('detail.eventDate'),
                    value: AppFormatters.dateLong(sub.nextDueDate),
                  ),
                  if (sub.dueTime != null)
                    (
                      icon: LucideIcons.clock,
                      label: context.tr('detail.time'),
                      value: AppFormatters.time(
                        sub.dueTime!.hour,
                        sub.dueTime!.minute,
                      ),
                    ),
                  (
                    icon: LucideIcons.timer,
                    label: context.tr('detail.countdown'),
                    value: countdown,
                  ),
                  if (sub.description.isNotEmpty)
                    (
                      icon: LucideIcons.fileText,
                      label: context.tr('detail.description'),
                      value: sub.description,
                    ),
                ]
              : [
                  (
                    icon: LucideIcons.calendar,
                    label: context.tr('detail.nextDue'),
                    value: sub.dueTime != null
                        ? AppFormatters.dateTimeLong(sub.dueAt)
                        : AppFormatters.dateLong(sub.nextDueDate),
                  ),
                  (
                    icon: LucideIcons.timer,
                    label: context.tr('detail.countdown'),
                    value: countdown,
                  ),
                  (
                    icon: LucideIcons.repeat,
                    label: context.tr('detail.billingCycle'),
                    value: sub.cycleLabel,
                  ),
                  (
                    icon: LucideIcons.layoutGrid,
                    label: context.tr('detail.category'),
                    value: sub.category.label,
                  ),
                  (
                    icon: LucideIcons.building2,
                    label: context.tr('detail.provider'),
                    value: sub.provider.isEmpty ? '—' : sub.provider,
                  ),
                  if (sub.country.isNotEmpty)
                    (
                      icon: LucideIcons.flag,
                      label: context.tr('detail.country'),
                      value: [
                        sub.countryFlag,
                        AppCountries.byCode(
                              sub.country,
                            )?.nameFor(AppFormatters.lang) ??
                            sub.country,
                      ].join(' ').trim(),
                    ),
                  if (sub.description.isNotEmpty)
                    (
                      icon: LucideIcons.mapPin,
                      label: context.tr('detail.description'),
                      value: sub.description,
                    ),
                ],
        ),
        if (!sub.isEvent) ...[
          const SizedBox(height: 16),
          _PaymentHistory(
            key: ValueKey('${sub.id}-${sub.status.name}'),
            subscriptionId: sub.id,
            currency: sub.currency,
          ),
        ],
        const SizedBox(height: 24),

        // --- Actions ---
        if (sub.status != SubscriptionStatus.paid)
          FilledButton.icon(
            onPressed: () => _markPaid(context),
            icon: const Icon(LucideIcons.check, size: 19),
            label: Text(
              context.tr(sub.isEvent ? 'detail.markDone' : 'detail.markPaid'),
            ),
          ),
        if (sub.status != SubscriptionStatus.paid) const SizedBox(height: 12),
        // Lien de paiement direct — ouvre le portail du
        // fournisseur (champ « Lien de paiement » du formulaire).
        if (sub.paymentUrl.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(sub.paymentUrl),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(LucideIcons.creditCard, size: 18),
            label: Text(context.tr('detail.payNow')),
          ),
        if (sub.paymentUrl.isNotEmpty) const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => showSubscriptionFormSheet(context, existing: sub),
          icon: const Icon(LucideIcons.pencil, size: 18),
          label: Text(context.tr('common.edit')),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _confirmDelete(context),
          icon: Icon(
            LucideIcons.trash2,
            size: 18,
            color: context.status.overdue,
          ),
          label: Text(
            context.tr('common.delete'),
            style: TextStyle(color: context.status.overdue),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: context.status.overdue.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _markPaid(BuildContext context) async {
    final result = await context.read<SubscriptionsCubit>().markPaid(
      subscription,
    );
    if (!context.mounted) return;
    toastification.show(
      context: context,
      type: result is Ok
          ? ToastificationType.success
          : ToastificationType.error,
      style: ToastificationStyle.flat,
      title: Text(
        result is Ok
            ? context.tr(subscription.isEvent ? 'toast.done' : 'toast.paid', {
                'name': subscription.name,
              })
            : switch (result) {
                Err(failure: final f) => f.localizedMessage,
                _ => context.tr('common.unexpected'),
              },
      ),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(LucideIcons.trash2, color: Theme.of(ctx).colorScheme.error),
        title: Text(ctx.tr('detail.deleteTitle')),
        content: Text(ctx.tr('detail.deleteBody', {'name': subscription.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(ctx.tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await context.read<SubscriptionsCubit>().delete(
      subscription,
    );
    if (!context.mounted) return;
    if (result is Ok) {
      context.pop();
    }
    toastification.show(
      context: context,
      type: result is Ok
          ? ToastificationType.success
          : ToastificationType.error,
      style: ToastificationStyle.flat,
      title: Text(
        result is Ok
            ? context.tr('detail.deleted')
            : switch (result) {
                Err(failure: final f) => f.localizedMessage,
                _ => context.tr('common.unexpected'),
              },
      ),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }
}

class _PaymentHistory extends StatefulWidget {
  const _PaymentHistory({
    super.key,
    required this.subscriptionId,
    required this.currency,
  });

  final String subscriptionId;
  final String currency;

  @override
  State<_PaymentHistory> createState() => _PaymentHistoryState();
}

class _PaymentHistoryState extends State<_PaymentHistory> {
  late Future<List<_PaymentEntry>> _future = _load();

  Future<List<_PaymentEntry>> _load() async {
    final response = await getIt<Dio>().get<dynamic>(
      ApiEndpoints.subscriptionHistory(widget.subscriptionId),
    );
    final raw = response.data;
    final items = raw is Map<String, dynamic>
        ? raw['results'] as List<dynamic>
        : raw as List<dynamic>;
    return items.map((item) {
      final json = item as Map<String, dynamic>;
      return _PaymentEntry(
        amount: double.parse(json['amount'].toString()),
        dueDate: DateTime.parse(json['due_date'] as String),
        paidAt: DateTime.parse(json['paid_at'] as String).toLocal(),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: FutureBuilder<List<_PaymentEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 64,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Row(
              children: [
                Expanded(child: Text(context.tr('detail.historyFail'))),
                IconButton(
                  tooltip: context.tr('common.retry'),
                  onPressed: () => setState(() => _future = _load()),
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                ),
              ],
            );
          }
          final entries = snapshot.data!;
          final months = <String, List<_PaymentEntry>>{};
          for (final entry in entries) {
            months
                .putIfAbsent(AppFormatters.monthYear(entry.dueDate), () => [])
                .add(entry);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.history, size: 19, color: scheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('detail.history'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (entries.isEmpty)
                Text(
                  context.tr('detail.historyEmpty'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                for (final month in months.entries) ...[
                  Text(
                    month.key.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final entry in month.value) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppFormatters.dateLong(entry.dueDate),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                context.tr('detail.paidOn', {
                                  'date': AppFormatters.dateLong(entry.paidAt),
                                }),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          AppFormatters.money(entry.amount, widget.currency),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (month.key != months.keys.last) const Divider(height: 20),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _PaymentEntry {
  const _PaymentEntry({
    required this.amount,
    required this.dueDate,
    required this.paidAt,
  });

  final double amount;
  final DateTime dueDate;
  final DateTime paidAt;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<({IconData icon, String label, String value})> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 52,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Icon(rows[i].icon, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.end,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
