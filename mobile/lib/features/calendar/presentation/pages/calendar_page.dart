import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_fade_in.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../subscriptions/domain/entities/subscription.dart';
import '../../../subscriptions/presentation/cubit/subscriptions_cubit.dart';
import '../../../subscriptions/presentation/widgets/subscription_tile.dart';

/// Onglet Calendrier : grille mensuelle, pastilles colorées par statut,
/// détail du jour sélectionné.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _visibleMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    context.read<SubscriptionsCubit>().ensureLoaded();
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendrier'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => context.read<SubscriptionsCubit>().refresh(),
            icon: const Icon(LucideIcons.refreshCw, size: 20),
          ),
        ],
      ),
      body: BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
        builder: (context, state) {
          if (state is SubscriptionsLoading || state is SubscriptionsInitial) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  SkeletonCard(height: 320),
                  SizedBox(height: 16),
                  Expanded(child: SkeletonListView(itemCount: 3)),
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

          final items = (state as SubscriptionsLoaded).items;
          final selected = _selectedDay;
          final dayItems = selected == null
              ? <Subscription>[]
              : items.where((s) => _sameDay(s.nextDueDate, selected)).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              AnimatedFadeIn(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radius + 4),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => _shiftMonth(-1),
                            icon: const Icon(LucideIcons.chevronLeft, size: 20),
                          ),
                          Text(
                            AppFormatters.monthYear(_visibleMonth),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _shiftMonth(1),
                            icon: const Icon(
                              LucideIcons.chevronRight,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _MonthGrid(
                        month: _visibleMonth,
                        items: items,
                        selected: _selectedDay,
                        onSelect: (d) => setState(() => _selectedDay = d),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // --- Légende des statuts ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Legend(color: context.status.dueSoon, label: 'À venir'),
                  const SizedBox(width: 16),
                  _Legend(color: context.status.paid, label: 'Payé'),
                  const SizedBox(width: 16),
                  _Legend(color: context.status.overdue, label: 'En retard'),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                selected == null
                    ? 'Sélectionnez un jour'
                    : AppFormatters.dateLong(selected),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (selected != null && dayItems.isEmpty)
                const EmptyState(
                  icon: LucideIcons.calendarOff,
                  title: 'Aucune échéance',
                  subtitle: 'Rien à payer ce jour-là.',
                )
              else
                ...dayItems.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SubscriptionTile(subscription: s),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final DateTime month;
  final List<Subscription> items;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = DateTime.now();

    // Dart : lundi = 1. On aligne la grille sur lundi.
    final firstDay = DateTime(month.year, month.month);
    final leading = firstDay.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Column(
      children: [
        Row(
          children: labels
              .map(
                (l) => Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _cell(r * 7 + c, today, theme)),
            ],
          ),
      ],
    );
  }

  Widget _cell(int index, DateTime today, ThemeData theme) {
    final leading = DateTime(month.year, month.month).weekday - 1;
    final dayNumber = index - leading + 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 42);
    }

    final day = DateTime(month.year, month.month, dayNumber);
    final isToday =
        day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    final isSelected =
        selected != null &&
        day.year == selected!.year &&
        day.month == selected!.month &&
        day.day == selected!.day;

    final dues = items.where(
      (s) =>
          s.nextDueDate.year == day.year &&
          s.nextDueDate.month == day.month &&
          s.nextDueDate.day == day.day,
    );

    return GestureDetector(
      onTap: () => onSelect(day),
      child: Container(
        height: 42,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : isToday
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isToday || isSelected
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: isSelected ? theme.colorScheme.onPrimary : null,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: dues
                  .take(3)
                  .map(
                    (s) => Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.white
                            : switch (s.status) {
                                SubscriptionStatus.paid =>
                                  AppColors.lightSuccess,
                                SubscriptionStatus.dueSoon =>
                                  AppColors.lightWarning,
                                SubscriptionStatus.overdue =>
                                  AppColors.lightDanger,
                              },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
