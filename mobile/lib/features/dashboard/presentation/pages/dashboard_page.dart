import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:toastification/toastification.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/storage/settings_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_converter.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/animated_fade_in.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../subscriptions/domain/entities/subscription.dart';
import '../../../subscriptions/presentation/cubit/subscriptions_cubit.dart';
import '../../../subscriptions/presentation/widgets/subscription_tile.dart';

/// Accueil — total du mois, stats rapides, prochaines échéances.
/// Données : SubscriptionsCubit partagé (API Django).
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Popup de rappel affiché une seule fois par session.
  bool _reminderShown = false;

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionsCubit>().ensureLoaded();
  }

  /// Popup in-app : rappelle les échéances urgentes dès que la
  /// liste est chargée — une seule fois par session.
  void _maybeShowReminder(List<Subscription> overdue) {
    if (_reminderShown || overdue.isEmpty) return;
    _reminderShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => _ReminderDialog(overdue: overdue),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final name = switch (state) {
              Authenticated(:final user) => user.firstName ?? user.email,
              _ => '',
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, $name',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  AppFormatters.dateLong(DateTime.now()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            );
          },
        ),
        toolbarHeight: 68,
        actions: [
          // Cloche → centre de notifications in-app, badge =
          // échéances en retard + à venir.
          BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
            builder: (context, state) {
              final count = (state.subscriptions ?? [])
                  .where((s) => s.status != SubscriptionStatus.paid)
                  .length;
              return IconButton(
                tooltip: 'Notifications',
                onPressed: () => context.push(AppRoutes.notifications),
                icon: Badge.count(
                  count: count,
                  isLabelVisible: count > 0,
                  child: const Icon(LucideIcons.bell, size: 22),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
        builder: (context, state) {
          final loading = state is! SubscriptionsLoaded;
          final items = state.subscriptions ?? [];

          if (state is SubscriptionsError) {
            return _ErrorView(message: state.message);
          }

          // Totaux regroupés PAR DEVISE — jamais de somme mêlant
          // FCFA et USD (ex. Starlink facturé en $ au Cameroun).
          Map<String, double> sumByCurrency(
            Iterable<Subscription> subs,
          ) {
            final map = <String, double>{};
            for (final s in subs) {
              map[s.currency] = (map[s.currency] ?? 0) + s.amount;
            }
            return map;
          }

          // Les rendez-vous n'ont pas de montant : exclus des totaux.
          final billed = items.where((s) => !s.isEvent).toList();
          final dueByCurrency = sumByCurrency(
            billed.where((s) => s.status != SubscriptionStatus.paid),
          );
          final spentByCurrency = sumByCurrency(
            billed.where((s) => s.status == SubscriptionStatus.paid),
          );
          // Budget : comparé uniquement à la devise principale du
          // workspace (les montants en USD ne gonflent pas le
          // budget FCFA).
          final mainCurrency = switch (context.read<AuthCubit>().state) {
            Authenticated(user: final u) =>
              u.workspace?.defaultCurrency ?? 'XAF',
            _ => 'XAF',
          };
          final spentMain = (spentByCurrency[mainCurrency] ?? 0) +
              (dueByCurrency[mainCurrency] ?? 0);
          final overdueSubs = items
              .where((s) => s.status == SubscriptionStatus.overdue)
              .toList();
          // Échéances à venir + rendez-vous non passés (quel que
          // soit leur statut), triés par date/heure.
          final now = DateTime.now();
          final upcoming = items
              .where(
                (s) => s.isEvent
                    ? s.status != SubscriptionStatus.overdue &&
                        !s.dueAt.isBefore(DateUtils.dateOnly(now))
                    : s.status == SubscriptionStatus.dueSoon,
              )
              .toList()
            ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
          final budget = getIt<SettingsStorage>().monthlyBudget;

          if (!loading) _maybeShowReminder(overdueSubs);

          return RefreshIndicator(
            onRefresh: () => context.read<SubscriptionsCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // --- Carte total : navy dégradé du logo ---
                if (loading)
                  const SkeletonCard(height: 190)
                else
                  AnimatedFadeIn(
                    child: _TotalCard(
                      dueByCurrency: dueByCurrency,
                      spentByCurrency: spentByCurrency,
                      mainCurrency: mainCurrency,
                      count: items.length,
                    ),
                  ),
                const SizedBox(height: 14),

                // --- Rappel : tenir la liste à jour ---
                if (!loading)
                  const AnimatedFadeIn(child: _UpdateHintCard()),
                if (!loading) const SizedBox(height: 14),

                // --- Alerte retards ---
                if (!loading && overdueSubs.isNotEmpty)
                  AnimatedFadeIn(
                    child: _OverdueBanner(subs: overdueSubs),
                  ),
                if (!loading && overdueSubs.isNotEmpty)
                  const SizedBox(height: 14),

                // --- Budget mensuel ---
                if (loading)
                  const SkeletonCard(height: 130)
                else
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 60),
                    child: _BudgetCard(
                      budget: budget,
                      spent: spentMain,
                    ),
                  ),
                const SizedBox(height: 14),

                // --- Dépenses par catégorie ---
                if (!loading && billed.isNotEmpty)
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 120),
                    child: _CategorySpend(items: billed),
                  ),
                if (!loading && billed.isNotEmpty) const SizedBox(height: 20),

                const SizedBox(height: 8),
                Text(
                  'Prochaines échéances',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (loading)
                  const SizedBox(height: 320, child: SkeletonListView(itemCount: 4))
                else
                  ...upcoming.take(4).toList().asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AnimatedFadeIn(
                        delay: Duration(milliseconds: 60 * entry.key),
                        child: SubscriptionTile(
                          subscription: entry.value,
                          onMarkPaid: () => _markPaid(context, entry.value),
                          onTap: () => context.push(
                            AppRoutes.subscriptionDetail(entry.value.id),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Retards : affichés sous les échéances pour action rapide.
                if (!loading)
                  ...overdueSubs.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SubscriptionTile(
                        subscription: s,
                        onMarkPaid: () => _markPaid(context, s),
                        onTap: () => context.push(
                          AppRoutes.subscriptionDetail(s.id),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
  Future<void> _markPaid(BuildContext context, Subscription sub) async {
    final result = await context.read<SubscriptionsCubit>().markPaid(sub);
    if (!context.mounted) return;
    toastification.show(
      context: context,
      type: switch (result) {
        Ok() => ToastificationType.success,
        Err() => ToastificationType.error,
      },
      style: ToastificationStyle.flat,
      title: Text(switch (result) {
        Ok() => '${sub.name} marqué comme payé.',
        Err(failure: final f) => f.message,
      }),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }
}

/// Carte rappel doux : incite à tenir la liste à jour —
/// nouvelles factures, abonnements oubliés, salaires…
class _UpdateHintCard extends StatelessWidget {
  const _UpdateHintCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(LucideIcons.bellPlus, size: 18, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Facture d\'eau, d\'électricité, salaire ou nouvel abonnement à suivre ? Pensez à mettre votre liste à jour.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau d'alerte : échéances en retard — action immédiate attendue.
class _OverdueBanner extends StatelessWidget {
  const _OverdueBanner({required this.subs});

  final List<Subscription> subs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = context.status.overdue;
    // Somme par devise — ex. "48 500 FCFA + 45 USD".
    final byCurrency = <String, double>{};
    for (final s in subs.where((s) => !s.isEvent)) {
      byCurrency[s.currency] = (byCurrency[s.currency] ?? 0) + s.amount;
    }
    final totalText = byCurrency.entries
        .map((e) => AppFormatters.money(e.value, e.key))
        .join(' + ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius - 4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${subs.length} échéance${subs.length > 1 ? 's' : ''} en retard${totalText.isEmpty ? '' : ' — $totalText'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Consommation budgétaire du mois : dépensé + à payer vs budget.
class _BudgetCard extends StatefulWidget {
  const _BudgetCard({required this.budget, required this.spent});

  final double budget;
  final double spent;

  @override
  State<_BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends State<_BudgetCard> {
  /// Le budget est saisi dans la devise principale du workspace.
  String get _mainCurrency => switch (context.read<AuthCubit>().state) {
    Authenticated(user: final u) =>
      u.workspace?.defaultCurrency ?? 'XAF',
    _ => 'XAF',
  };

  Future<void> _editBudget() async {
    final controller = TextEditingController(
      text: widget.budget > 0 ? widget.budget.round().toString() : '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          LucideIcons.wallet,
          color: Theme.of(ctx).colorScheme.primary,
        ),
        title: const Text('Budget mensuel'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Montant',
            suffixText: _mainCurrency,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(
              double.tryParse(
                controller.text.replaceAll(' ', '').replaceAll(',', '.'),
              ),
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (value != null && value >= 0) {
      await getIt<SettingsStorage>().setMonthlyBudget(value);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = widget.budget > 0
        ? (widget.spent / widget.budget).clamp(0.0, 1.0)
        : 0.0;
    final over = widget.budget > 0 && widget.spent > widget.budget;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.wallet, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Budget du mois',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _editBudget,
                icon: const Icon(LucideIcons.pencil, size: 14),
                label: Text(widget.budget > 0 ? 'Modifier' : 'Définir'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.budget <= 0)
            Text(
              'Définissez votre budget mensuel pour suivre la consommation de vos dépenses.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
                color: over ? context.status.overdue : scheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppFormatters.money(widget.spent, _mainCurrency)} engagés',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: over ? context.status.overdue : null,
                  ),
                ),
                Text(
                  '${(ratio * 100).round()} % de ${AppFormatters.money(widget.budget, _mainCurrency)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (over)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Dépassement de ${AppFormatters.money(widget.spent - widget.budget, _mainCurrency)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.status.overdue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Dépenses par catégorie — barres de progression compactes.
class _CategorySpend extends StatelessWidget {
  const _CategorySpend({required this.items});

  final List<Subscription> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Regroupement (catégorie, devise) — une ligne par combinaison
    // pour ne jamais fusionner FCFA et USD dans une même barre.
    final byCategory = <(SubscriptionCategory, String), double>{};
    for (final s in items) {
      final key = (s.category, s.currency);
      byCategory[key] = (byCategory[key] ?? 0) + s.amount;
    }
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dépenses par catégorie',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...entries.take(5).map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(e.key.$1.icon, size: 15, color: e.key.$1.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.key.$1.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        AppFormatters.money(e.value, e.key.$2),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (e.value / max).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: scheme.outlineVariant.withValues(
                        alpha: 0.35,
                      ),
                      color: e.key.$1.color,
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

/// Carte héros : dépensé + reste à payer du mois —
/// dégradé navy + accent émeraude.
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.dueByCurrency,
    required this.spentByCurrency,
    required this.mainCurrency,
    required this.count,
  });

  /// Totaux par devise — ex. {XAF: 850000, USD: 45}.
  /// On n'additionne JAMAIS deux devises ensemble.
  final Map<String, double> dueByCurrency;
  final Map<String, double> spentByCurrency;

  /// Devise locale de l'utilisateur (workspace.defaultCurrency) —
  /// les gros chiffres de la carte sont convertis dedans.
  final String mainCurrency;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1F44), Color(0xFF14306B)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius + 4),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  AppFormatters.monthYear(DateTime.now()).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.emerald,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                LucideIcons.wallet,
                color: Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dépensé ce mois',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _ConvertedAmount(
                      byCurrency: spentByCurrency,
                      target: mainCurrency,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (spentByCurrency.length > 1)
                      Text(
                        _breakdown(spentByCurrency),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reste à payer',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.emerald.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _ConvertedAmount(
                      byCurrency: dueByCurrency,
                      target: mainCurrency,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (dueByCurrency.length > 1)
                      Text(
                        _breakdown(dueByCurrency),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$count abonnement${count > 1 ? 's' : ''} suivi${count > 1 ? 's' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.cloudOff, size: 40),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => context.read<SubscriptionsCubit>().refresh(),
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

/// Popup de rappel in-app : liste les échéances en retard et
/// propose d'ouvrir le centre de notifications.
class _ReminderDialog extends StatelessWidget {
  const _ReminderDialog({required this.overdue});

  final List<Subscription> overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = context.status.overdue;
    final byCurrency = <String, double>{};
    for (final s in overdue.where((s) => !s.isEvent)) {
      byCurrency[s.currency] = (byCurrency[s.currency] ?? 0) + s.amount;
    }
    final totalText = byCurrency.entries
        .map((e) => AppFormatters.money(e.value, e.key))
        .join(' + ');

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius + 4),
      ),
      title: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.bellRing, color: color, size: 26),
          ),
          const SizedBox(height: 14),
          const Text('Rappel de paiement', textAlign: TextAlign.center),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${overdue.length} échéance${overdue.length > 1 ? 's' : ''} en retard${totalText.isEmpty ? '' : ' — $totalText au total'}.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          for (final s in overdue.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(s.category.icon, size: 15, color: s.category.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        if (s.description.isNotEmpty)
                          Text(
                            s.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    s.isEvent
                        ? (s.dueTime != null
                            ? AppFormatters.dateTimeLong(s.dueAt)
                            : AppFormatters.dateLong(s.nextDueDate))
                        : AppFormatters.money(s.amount, s.currency),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (overdue.length > 3)
            Text(
              'et ${overdue.length - 3} autre${overdue.length - 3 > 1 ? 's' : ''}…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Plus tard'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.push(AppRoutes.notifications);
          },
          child: const Text('Voir les échéances'),
        ),
      ],
    );
  }
}

/// Résumé multi-devises en petit : "850 000 FCFA + 45 $".
String _breakdown(Map<String, double> byCurrency) => byCurrency.entries
    .map((e) => AppFormatters.money(e.value, e.key))
    .join(' + ');

/// Montant converti dans la devise locale de l'utilisateur.
/// Somme toutes les entrées APRÈS conversion (taux réels /rates/).
/// Si la conversion est impossible (hors-ligne…), affiche la
/// somme dans la devise cible uniquement — jamais de mélange.
class _ConvertedAmount extends StatelessWidget {
  const _ConvertedAmount({
    required this.byCurrency,
    required this.target,
    this.style,
  });

  final Map<String, double> byCurrency;
  final String target;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (byCurrency.isEmpty) {
      return Text(AppFormatters.money(0, target), style: style);
    }
    if (byCurrency.length == 1) {
      final e = byCurrency.entries.first;
      return Text(AppFormatters.money(e.value, e.key), style: style);
    }
    return FutureBuilder<double>(
      future: getIt<CurrencyConverter>().convertAll(
        byCurrency.entries.map(
          (e) => (amount: e.value, currency: e.key),
        ),
        target,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Pendant le chargement : première devise seule,
          // plutôt qu'un chiffre incertain.
          final e = byCurrency.entries.first;
          return Text(AppFormatters.money(e.value, e.key), style: style);
        }
        return Text(
          AppFormatters.money(snapshot.data!, target),
          style: style,
        );
      },
    );
  }
}
