import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/router/app_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/animated_fade_in.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../domain/entities/subscription.dart';
import '../cubit/subscriptions_cubit.dart';
import '../widgets/subscription_tile.dart';

/// Onglet Abonnements : recherche, filtres par statut, liste,
/// et ajout via bottom sheet. Les données viennent du
/// SubscriptionsCubit partagé (API Django).
class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  String _query = '';
  SubscriptionStatus? _filter;

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionsCubit>().ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abonnements'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push(AppRoutes.notifications),
            icon: const Icon(LucideIcons.bell, size: 20),
          ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => context.read<SubscriptionsCubit>().refresh(),
            icon: const Icon(LucideIcons.refreshCw, size: 20),
          ),
        ],
      ),
      // Marge basse renforcée : le bouton flotte nettement
      // AU-DESSUS de la barre de navigation pill — plus de
      // chevauchement sur aucun écran.
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddSheet(context),
          icon: const Icon(LucideIcons.plus, size: 20),
          label: const Text('Ajouter'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un abonnement…',
                    prefixIcon: Icon(LucideIcons.search, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tous',
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      _FilterChip(
                        label: 'Payés',
                        selected: _filter == SubscriptionStatus.paid,
                        onTap: () => setState(
                          () => _filter = SubscriptionStatus.paid,
                        ),
                      ),
                      _FilterChip(
                        label: 'À venir',
                        selected: _filter == SubscriptionStatus.dueSoon,
                        onTap: () => setState(
                          () => _filter = SubscriptionStatus.dueSoon,
                        ),
                      ),
                      _FilterChip(
                        label: 'En retard',
                        selected: _filter == SubscriptionStatus.overdue,
                        onTap: () => setState(
                          () => _filter = SubscriptionStatus.overdue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
              builder: (context, state) {
                return switch (state) {
                  SubscriptionsLoading() || SubscriptionsInitial() =>
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: SkeletonListView(),
                    ),
                  SubscriptionsError(:final message) => EmptyState(
                    icon: LucideIcons.cloudOff,
                    title: 'Chargement impossible',
                    subtitle: message,
                    action: FilledButton.tonalIcon(
                      onPressed: () =>
                          context.read<SubscriptionsCubit>().refresh(),
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      label: const Text('Réessayer'),
                    ),
                  ),
                  SubscriptionsLoaded(:final items) =>
                    _buildList(context, items),
                };
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Subscription> items) {
    final q = _query.trim().toLowerCase();
    final filtered = items.where((s) {
      final matchesQuery =
          q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.provider.toLowerCase().contains(q);
      final matchesFilter = _filter == null || s.status == _filter;
      return matchesQuery && matchesFilter;
    }).toList()..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    if (items.isEmpty) {
      // Liste vide : on guide l'utilisateur vers l'action principale
      // plutôt que de le laisser sur une page morte.
      return EmptyState(
        icon: LucideIcons.repeat,
        title: 'Aucun abonnement',
        subtitle:
            'Ajoutez votre première échéance récurrente pour commencer le suivi.',
        action: FilledButton.icon(
          onPressed: () => _showAddSheet(context),
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('Ajouter un abonnement'),
        ),
      );
    }
    if (filtered.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.searchX,
        title: 'Aucun résultat',
        subtitle: 'Modifiez la recherche ou les filtres.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<SubscriptionsCubit>().refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => AnimatedFadeIn(
          delay: Duration(milliseconds: 40 * index.clamp(0, 8)),
          child: SubscriptionTile(
            subscription: filtered[index],
            onMarkPaid: () => _markPaid(context, filtered[index]),
            onTap: () => context.push(
              AppRoutes.subscriptionDetail(filtered[index].id),
            ),
          ),
        ),
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

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: context.read<SubscriptionsCubit>(),
        child: const _AddSubscriptionSheet(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        labelStyle: TextStyle(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
    );
  }
}

/// Formulaire d'ajout en bottom sheet — validé localement,
/// envoyé au SubscriptionsCubit.
class _AddSubscriptionSheet extends StatefulWidget {
  const _AddSubscriptionSheet();

  @override
  State<_AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends State<_AddSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _provider = TextEditingController();
  final _amount = TextEditingController();
  SubscriptionCategory _category = SubscriptionCategory.software;
  BillingCycle _cycle = BillingCycle.monthly;
  // Date de la PREMIÈRE échéance — peut être dans le passé
  // (ex. serveur loué dimanche, saisi mercredi) : la prochaine
  // échéance est alors calculée automatiquement.
  DateTime _firstDue = DateTime.now().add(const Duration(days: 30));
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _provider.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Prochaine échéance réelle : on avance la première échéance
  /// cycle par cycle jusqu'à une date >= aujourd'hui.
  DateTime get _nextDue {
    var d = _firstDue;
    final today = DateUtils.dateOnly(DateTime.now());
    var guard = 0;
    while (d.isBefore(today) && guard++ < 120) {
      d = switch (_cycle) {
        BillingCycle.monthly => DateTime(d.year, d.month + 1, d.day),
        BillingCycle.quarterly => DateTime(d.year, d.month + 3, d.day),
        BillingCycle.yearly => DateTime(d.year + 1, d.month, d.day),
      };
    }
    return d;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDue,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Première échéance',
    );
    if (picked != null) setState(() => _firstDue = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    final result = await context.read<SubscriptionsCubit>().create(
      name: _name.text.trim(),
      provider: _provider.text.trim(),
      category: _category,
      amount:
          double.tryParse(_amount.text.replaceAll(' ', '').replaceAll(',', '.')) ??
          0,
      nextDueDate: _nextDue,
      cycle: _cycle,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result is Ok) {
      Navigator.of(context).pop();
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.flat,
        title: const Text('Abonnement ajouté.'),
        autoCloseDuration: const Duration(seconds: 3),
      );
    } else if (result case Err(failure: final f)) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.flat,
        title: Text(f.message),
        autoCloseDuration: const Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nouvel abonnement',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  hintText: 'Ex. Loyer siège social',
                  prefixIcon: Icon(LucideIcons.tag, size: 20),
                ),
                validator: _required,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _provider,
                decoration: const InputDecoration(
                  labelText: 'Fournisseur',
                  hintText: 'Ex. ENEO, Orange…',
                  prefixIcon: Icon(LucideIcons.building2, size: 20),
                ),
                validator: _required,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Montant',
                        suffixText: 'FCFA',
                        prefixIcon: Icon(LucideIcons.banknote, size: 20),
                      ),
                      validator: (v) =>
                          (double.tryParse(
                                (v ?? '').replaceAll(' ', '').replaceAll(',', '.'),
                              ) ??
                              0) >
                              0
                          ? null
                          : 'Montant invalide',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<BillingCycle>(
                      initialValue: _cycle,
                      decoration: const InputDecoration(labelText: 'Cycle'),
                      items: BillingCycle.values
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                switch (c) {
                                  BillingCycle.monthly => 'Mensuel',
                                  BillingCycle.quarterly => 'Trimestriel',
                                  BillingCycle.yearly => 'Annuel',
                                },
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (c) => setState(() => _cycle = c!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<SubscriptionCategory>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  prefixIcon: Icon(LucideIcons.layoutGrid, size: 20),
                ),
                items: SubscriptionCategory.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(c.icon, size: 18, color: c.color),
                            const SizedBox(width: 10),
                            Text(c.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (c) => setState(() => _category = c!),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(LucideIcons.calendar, size: 18),
                label: Text(
                  'Première échéance : ${AppFormatters.dateLong(_firstDue)}',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    LucideIcons.info,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Prochaine échéance calculée : ${AppFormatters.dateLong(_nextDue)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.plus, size: 19),
                label: Text(_submitting ? 'Ajout…' : 'Ajouter l\'abonnement'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Champ obligatoire' : null;
}
