import 'dart:async';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/navigation/tab_reselect.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_fade_in.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../subscriptions/domain/entities/subscription.dart';
import '../../../subscriptions/presentation/cubit/subscriptions_cubit.dart';
import '../../../workspace/data/datasources/workspace_remote_datasource.dart';

/// Onglet Rapports : répartition par catégorie (donut)
/// + prévision de dépenses sur 6 mois (barres).
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  /// Devise affichée — les rapports ne mélangent JAMAIS deux devises
  /// (un total FCFA+USD n'a pas de sens comptable).
  String? _currency;

  /// Scroll principal — re-tap sur « Rapports » remonte en
  /// haut et rafraîchit silencieusement.
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionsCubit>().ensureLoaded();
    getIt<TabReselect>().tick.addListener(_onTabReselect);
    // Devise principale du workspace comme défaut.
    _currency = switch (context.read<AuthCubit>().state) {
      Authenticated(user: final u) => u.workspace?.defaultCurrency,
      _ => null,
    };
  }

  void _onTabReselect() {
    if (getIt<TabReselect>().lastIndex != 3 || !mounted) return;
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
    unawaited(context.read<SubscriptionsCubit>().refresh(quiet: true));
  }

  @override
  void dispose() {
    getIt<TabReselect>().tick.removeListener(_onTabReselect);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.reports'))),
      body: BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
        builder: (context, state) {
          if (state is SubscriptionsLoading || state is SubscriptionsInitial) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  SkeletonCard(height: 260),
                  SizedBox(height: 16),
                  SkeletonCard(height: 240),
                ],
              ),
            );
          }
          if (state is SubscriptionsError) {
            return EmptyState(
              icon: LucideIcons.cloudOff,
              title: context.tr('common.loadError'),
              subtitle: state.message,
            );
          }

          final all = (state as SubscriptionsLoaded).items;
          if (all.isEmpty) {
            return EmptyState(
              icon: LucideIcons.chartColumn,
              title: context.tr('reports.noData'),
              subtitle: context.tr('reports.noDataSub'),
            );
          }

          // Rendez-vous : pas de montant — listés à part, par
          // date/heure. Les graphiques ne portent que sur le facturé.
          final events = all.where((s) => s.isEvent).toList()
            ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
          final billed = all.where((s) => !s.isEvent).toList();

          // Devises présentes dans les données.
          final currencies = billed.map((s) => s.currency).toSet().toList()
            ..sort();
          final active = currencies.contains(_currency)
              ? _currency!
              : (currencies.isNotEmpty ? currencies.first : null);
          // Toutes les analyses ne portent que sur cette devise.
          final items = billed.where((s) => s.currency == active).toList();

          return ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              32 + AppShell.barInset,
            ),
            children: [
              if (events.isNotEmpty)
                AnimatedFadeIn(child: _UpcomingEvents(events: events)),
              if (events.isNotEmpty) const SizedBox(height: 20),
              if (active == null)
                EmptyState(
                  icon: LucideIcons.chartColumn,
                  title: context.tr('reports.noExpenses'),
                  subtitle: context.tr('reports.noExpensesSub'),
                )
              else ...[
                // Sélecteur de devise — visible seulement si >1.
                if (currencies.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final c in currencies)
                          ChoiceChip(
                            label: Text(c),
                            selected: c == active,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _currency = c),
                          ),
                      ],
                    ),
                  ),
                AnimatedFadeIn(
                  child: _CategoryDonut(items: items, currency: active),
                ),
                const SizedBox(height: 20),
                AnimatedFadeIn(
                  delay: const Duration(milliseconds: 100),
                  child: _MonthlyForecast(items: items, currency: active),
                ),
                const SizedBox(height: 20),
                // Prévision de trésorerie 90 j (étude §C) — solde
                // de départ + échéances projetées → alerte
                // « solde insuffisant ».
                // Exports professionnels (étude §F) : journal
                // comptable Excel + rapport mensuel PDF —
                // téléchargés avec l'auth de l'app puis partagés.
                AnimatedFadeIn(
                  child: _ExportCard(),
                ),
                const SizedBox(height: 20),
                AnimatedFadeIn(
                  child: _TreasuryCard(currency: active),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Liste des rendez-vous : date + heure, sans montant.
class _UpcomingEvents extends StatelessWidget {
  const _UpcomingEvents({required this.events});

  final List<Subscription> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _ChartCard(
      title: context.tr('reports.events'),
      child: Column(
        children: [
          for (final e in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: e.category.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      e.category.icon,
                      size: 18,
                      color: e.category.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          e.dueTime != null
                              ? AppFormatters.dateTimeLong(e.dueAt)
                              : AppFormatters.dateLong(e.nextDueDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppFormatters.relativeDay(e.nextDueDate),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius + 4),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

/// Donut : part de chaque catégorie dans les dépenses.
class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({required this.items, required this.currency});

  final List<Subscription> items;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byCategory = <SubscriptionCategory, double>{};
    for (final s in items) {
      byCategory[s.category] = (byCategory[s.category] ?? 0) + s.amount;
    }
    final total = byCategory.values.fold(0.0, (a, b) => a + b);
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _ChartCard(
      title: context.tr('reports.byCategory'),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 52,
                sections: entries
                    .map(
                      (e) => PieChartSectionData(
                        value: e.value,
                        color: e.key.color,
                        radius: 26,
                        showTitle: false,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          // Label central superposé via Stack serait fragile :
          // le total est affiché sous le donut.
          const SizedBox(height: 8),
          Text(
            AppFormatters.money(total, currency),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            context.tr('reports.perMonth'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ...entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: e.key.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.key.label)),
                  Text(
                    '${(e.value / total * 100).round()} %',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppFormatters.money(e.value, currency),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// L'abonnement tombe-t-il dans le mois [m] ? Projette les cycles
/// récurrents depuis la prochaine échéance, en respectant la
/// fin de contrat éventuelle.
bool _dueInMonth(Subscription s, DateTime m) {
  final d = s.nextDueDate;
  final end = s.endDate;
  if (end != null &&
      DateTime(m.year, m.month).isAfter(DateTime(end.year, end.month))) {
    return false;
  }
  // Jamais avant la prochaine échéance connue.
  if (DateTime(m.year, m.month).isBefore(DateTime(d.year, d.month))) {
    return false;
  }
  return switch (s.cycle) {
    BillingCycle.monthly => true,
    // Quotidien et hebdomadaire : une échéance tombe forcément
    // dans chaque mois.
    BillingCycle.daily || BillingCycle.weekly => true,
    BillingCycle.quarterly =>
      ((m.year - d.year) * 12 + (m.month - d.month)) % 3 == 0,
    BillingCycle.yearly => m.month == d.month,
    BillingCycle.once => m.year == d.year && m.month == d.month,
  };
}

/// Barres : prévision des échéances sur les 6 prochains mois.
class _MonthlyForecast extends StatelessWidget {
  const _MonthlyForecast({required this.items, required this.currency});

  final List<Subscription> items;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Agrège les montants par mois d'échéance sur 6 mois glissants.
    // Un abonnement récurrent se projette : mensuel → chaque mois,
    // trimestriel → 1 mois sur 3, annuel → même mois chaque année.
    final months = List.generate(6, (i) => DateTime(now.year, now.month + i));
    final totals = months.map((m) {
      return items
          .where((s) => _dueInMonth(s, m))
          .fold(0.0, (sum, s) => sum + s.amount);
    }).toList();
    final maxY = totals.fold(0.0, (a, b) => a > b ? a : b);

    return _ChartCard(
      title: context.tr('reports.forecast'),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: maxY == 0 ? 1 : maxY * 1.2,
            alignment: BarChartAlignment.spaceAround,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, _) {
                    final i = value.toInt();
                    if (i < 0 || i >= months.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppFormatters.monthShort(months[i]),
                          maxLines: 1,
                          softWrap: false,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  AppFormatters.money(rod.toY, currency),
                  const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < months.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: totals[i],
                      width: 22,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xFF0B9B6C), Color(0xFF34D399)],
                      ),
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

/// Prévision de trésorerie (étude §C) : solde de départ saisi +
/// échéances projetées sur 30/60/90 j → solde final, solde
/// minimum, première date « solde insuffisant ».
class _TreasuryCard extends StatefulWidget {
  const _TreasuryCard({required this.currency});

  final String currency;

  @override
  State<_TreasuryCard> createState() => _TreasuryCardState();
}

class _TreasuryCardState extends State<_TreasuryCard> {
  final _start = TextEditingController();
  int _days = 90;
  Map<String, dynamic>? _result;
  bool _loading = false;

  @override
  void dispose() {
    _start.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    try {
      final data = await getIt<WorkspaceRemoteDataSource>().treasury(
        days: _days,
        startBalance: double.tryParse(
              _start.text.trim().replaceAll(',', '.'),
            ) ??
            0,
      );
      if (mounted) setState(() => _result = data);
    } catch (_) {
      if (mounted) setState(() => _result = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = _result;
    final firstNeg = r?['first_negative_date'] as String?;
    final endBal = (r?['end_balance'] as num?)?.toDouble();
    final base = '${r?['base_currency'] ?? widget.currency}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.landmark, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                context.tr('tre.title'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _start,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr('tre.start'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<int>(
                segments: [
                  for (final d in const [30, 60, 90])
                    ButtonSegment(value: d, label: Text('${d}j')),
                ],
                selected: {_days},
                onSelectionChanged: (s) =>
                    setState(() => _days = s.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _run,
            icon: const Icon(LucideIcons.play, size: 16),
            label: Text(context.tr('tre.run')),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (r != null) ...[
            const SizedBox(height: 12),
            Text(
              '${context.tr('tre.planned')}: '
              '${AppFormatters.money((r['total_planned'] as num?)?.toDouble() ?? 0, base)} · '
              '${r['events']} ${context.tr('tre.events')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${context.tr('tre.end')}: '
              '${AppFormatters.money(endBal ?? 0, base)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: (endBal ?? 0) < 0 ? scheme.error : scheme.primary,
              ),
            ),
            if (firstNeg != null) ...[
              const SizedBox(height: 6),
              Text(
                context.tr('tre.negative', {'date': firstNeg}),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Exports professionnels (étude §F) : journal comptable Excel
/// et rapport mensuel PDF — téléchargés via Dio (auth) dans le
/// dossier temporaire puis partagés (share_plus).
class _ExportCard extends StatefulWidget {
  @override
  State<_ExportCard> createState() => _ExportCardState();
}

class _ExportCardState extends State<_ExportCard> {
  String? _busy;

  Future<void> _sendReport() async {
    final okMsg = context.tr('exp.sent');
    final errMsg = context.tr('exp.sendError');
    setState(() => _busy = 'mail');
    try {
      final res = await getIt<WorkspaceRemoteDataSource>()
          .sendMonthlyReport();
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: Text(
            res['sent_to'] != null
                ? '$okMsg → ${res['sent_to']}'
                : okMsg,
          ),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (_) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text(errMsg),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _export(String format) async {
    final okMsg = context.tr('exp.shared');
    final errMsg = context.tr('exp.error');
    setState(() => _busy = format);
    try {
      final bytes = await getIt<WorkspaceRemoteDataSource>()
          .exportBytes(format);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/abonex_rapport.${format == 'xlsx' ? 'xlsx' : 'pdf'}',
      );
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: Text(okMsg),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    } catch (_) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text(errMsg),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.fileDown,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('exp.title'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy != null
                      ? null
                      : () => _export('xlsx'),
                  icon: const Icon(LucideIcons.sheet, size: 16),
                  label: Text(context.tr('exp.xlsx')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _busy != null
                      ? null
                      : () => _export('pdf'),
                  icon: const Icon(LucideIcons.fileText, size: 16),
                  label: Text(context.tr('exp.pdf')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Rapport mensuel par e-mail au propriétaire (étude
          // §F/G) — nécessite EMAIL_HOST configuré côté serveur.
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _busy != null ? null : _sendReport,
              icon: const Icon(LucideIcons.mail, size: 16),
              label: Text(context.tr('exp.send')),
            ),
          ),
        ],
      ),
    );
  }
}
