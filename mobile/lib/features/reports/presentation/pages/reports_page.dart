import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_fade_in.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../subscriptions/domain/entities/subscription.dart';
import '../../../subscriptions/presentation/cubit/subscriptions_cubit.dart';

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

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionsCubit>().ensureLoaded();
    // Devise principale du workspace comme défaut.
    _currency = switch (context.read<AuthCubit>().state) {
      Authenticated(user: final u) => u.workspace?.defaultCurrency,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapports')),
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
              title: 'Chargement impossible',
              subtitle: state.message,
            );
          }

          final all = (state as SubscriptionsLoaded).items;
          if (all.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.chartColumn,
              title: 'Pas de données',
              subtitle: 'Ajoutez des abonnements pour voir les rapports.',
            );
          }

          // Devises présentes dans les données.
          final currencies = all.map((s) => s.currency).toSet().toList()
            ..sort();
          final active =
              _currency ?? currencies.first;
          // Toutes les analyses ne portent que sur cette devise.
          final items =
              all.where((s) => s.currency == active).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
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
                          onSelected: (_) =>
                              setState(() => _currency = c),
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
            ],
          );
        },
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
      title: 'Répartition par catégorie',
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
            'par mois (équivalent)',
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
    final months = List.generate(6, (i) => DateTime(now.year, now.month + i));
    final totals = months.map((m) {
      return items
          .where(
            (s) =>
                s.nextDueDate.year == m.year && s.nextDueDate.month == m.month,
          )
          .fold(0.0, (sum, s) => sum + s.amount);
    }).toList();
    final maxY = totals.fold(0.0, (a, b) => a > b ? a : b);

    return _ChartCard(
      title: 'Échéances des 6 prochains mois',
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: maxY == 0 ? 1 : maxY * 1.2,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final i = value.toInt();
                    if (i < 0 || i >= months.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        AppFormatters.monthYear(months[i]).split(' ').first,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
