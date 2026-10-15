import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/animated_fade_in.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../workspace/data/datasources/workspace_remote_datasource.dart';
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
            tooltip: 'Import & intégrations',
            onPressed: () => context.push(AppRoutes.integrations),
            icon: const Icon(LucideIcons.plugZap, size: 20),
          ),
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
  // Devise de l'abonnement — pré-remplie avec la devise principale
  // du workspace, modifiable (un compte peut suivre EUR + FCFA).
  String _currency = 'XAF';
  // Suggestions de fournisseurs selon le pays du workspace.
  List<Map<String, dynamic>> _providerSuggestions = [];
  // Date de la PREMIÈRE échéance — peut être dans le passé
  // (ex. serveur loué dimanche, saisi mercredi) : la prochaine
  // échéance est alors calculée automatiquement.
  DateTime _firstDue = DateTime.now().add(const Duration(days: 30));
  // Date de prise réelle de l'abonnement — null = inconnue.
  DateTime? _startDate;
  // Fin de contrat éventuelle — null = sans fin.
  DateTime? _endDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Devise principale du workspace comme défaut intelligent.
    final workspace = switch (context.read<AuthCubit>().state) {
      Authenticated(user: final u) => u.workspace,
      _ => null,
    };
    if (workspace?.defaultCurrency?.isNotEmpty ?? false) {
      _currency = workspace!.defaultCurrency!;
    }
    // Fournisseurs connus du pays → autocomplétion du champ.
    getIt<WorkspaceRemoteDataSource>()
        .providerCatalog()
        .then((list) {
          if (mounted) setState(() => _providerSuggestions = list);
        })
        .onError((_, _) {});
  }

  /// Devises proposées : principale + secondaires du workspace.
  List<String> get _currencies {
    final workspace = switch (context.read<AuthCubit>().state) {
      Authenticated(user: final u) => u.workspace,
      _ => null,
    };
    final list = <String>{
      if (workspace?.defaultCurrency?.isNotEmpty ?? false)
        workspace!.defaultCurrency!,
      ...?workspace?.extraCurrencies,
      'XAF', 'EUR', 'USD',
    }.toList();
    return list;
  }

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
        // Événement ponctuel : la première échéance EST l'échéance.
        BillingCycle.once => today,
      };
      if (_cycle == BillingCycle.once) break;
    }
    return _cycle == BillingCycle.once ? _firstDue : d;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Date de prise de l\'abonnement',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // La première échéance suit la date de prise par défaut.
        _firstDue = picked;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _endDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
      helpText: 'Fin du contrat',
    );
    if (picked != null) setState(() => _endDate = picked);
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
      currency: _currency,
      startDate: _startDate,
      endDate: _endDate,
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
              // Fournisseur avec suggestions adaptées au pays
              // (ENEO/Camwater pour le Cameroun, EDF pour la France…).
              Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (o) => o['name'] as String,
                optionsBuilder: (value) {
                  final q = value.text.toLowerCase();
                  if (q.isEmpty) return _providerSuggestions;
                  return _providerSuggestions.where(
                    (p) => (p['name'] as String)
                        .toLowerCase()
                        .contains(q),
                  );
                },
                onSelected: (option) {
                  _provider.text = option['name'] as String;
                  final cat = option['category'] as String?;
                  if (cat != null) {
                    setState(
                      () => _category = SubscriptionCategory.parse(cat),
                    );
                  }
                },
                fieldViewBuilder: (context, controller, focus, _) {
                  controller.addListener(() => _provider.text = controller.text);
                  return TextFormField(
                    controller: controller,
                    focusNode: focus,
                    decoration: const InputDecoration(
                      labelText: 'Fournisseur',
                      hintText: 'Ex. ENEO, OVH, EDF…',
                      prefixIcon: Icon(LucideIcons.building2, size: 20),
                    ),
                    validator: _required,
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Montant',
                        prefixIcon:
                            const Icon(LucideIcons.banknote, size: 20),
                        suffixIcon: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currency,
                            items: _currencies
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _currency = v!),
                          ),
                        ),
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
                                  BillingCycle.once => 'Une seule fois',
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
                      _cycle == BillingCycle.once
                          ? 'Échéance unique : ${AppFormatters.dateLong(_firstDue)}'
                          : 'Prochaine échéance calculée : ${AppFormatters.dateLong(_nextDue)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Date de prise réelle — optionnelle, peut être inconnue.
              OutlinedButton.icon(
                onPressed: _pickStartDate,
                icon: const Icon(LucideIcons.calendarPlus, size: 18),
                label: Text(
                  _startDate == null
                      ? 'Date de prise (optionnel — ex. dimanche dernier)'
                      : 'Pris le : ${AppFormatters.dateLong(_startDate!)}',
                ),
              ),
              if (_startDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _startDate = null),
                    child: const Text('Date inconnue'),
                  ),
                ),
              // Fin de contrat — optionnelle (CDD, abonnement à durée…).
              OutlinedButton.icon(
                onPressed: _pickEndDate,
                icon: const Icon(LucideIcons.calendarOff, size: 18),
                label: Text(
                  _endDate == null
                      ? 'Fin du contrat (optionnel)'
                      : 'Fin le : ${AppFormatters.dateLong(_endDate!)}',
                ),
              ),
              if (_endDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _endDate = null),
                    child: const Text('Sans date de fin'),
                  ),
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
