import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/data/countries.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/router/app_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/animated_fade_in.dart';
import '../../../../core/widgets/app_shell.dart';
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
  // Onglet affiché : abonnements facturés ou rendez-vous —
  // les deux ne se mélangent jamais dans la même liste.
  bool _showEvents = false;

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionsCubit>().ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('nav.subscriptions')),
        actions: [
          IconButton(
            tooltip: context.tr('subs.integrations'),
            onPressed: () => context.push(AppRoutes.integrations),
            icon: const Icon(LucideIcons.plugZap, size: 20),
          ),
          IconButton(
            tooltip: context.tr('nav.notifications'),
            onPressed: () => context.push(AppRoutes.notifications),
            icon: const Icon(LucideIcons.bell, size: 20),
          ),
          IconButton(
            tooltip: context.tr('common.refresh'),
            onPressed: () => context.read<SubscriptionsCubit>().refresh(),
            icon: const Icon(LucideIcons.refreshCw, size: 20),
          ),
        ],
      ),
      // Marge basse renforcée : le bouton flotte nettement
      // AU-DESSUS de la barre de navigation pill — plus de
      // chevauchement sur aucun écran.
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8 + AppShell.barInset),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddSheet(context),
          icon: const Icon(LucideIcons.plus, size: 20),
          label: Text(context.tr('common.add')),
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
                  decoration: InputDecoration(
                    hintText: context.tr('subs.search'),
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                // Sélecteur de type : chaque onglet garde sa
                // recherche et ses filtres de statut.
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(LucideIcons.repeat, size: 17),
                        label: Text(context.tr('subs.tabSubs')),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(LucideIcons.calendarClock, size: 17),
                        label: Text(context.tr('subs.tabEvents')),
                      ),
                    ],
                    selected: {_showEvents},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _showEvents = s.first),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: context.tr('filter.all'),
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      _FilterChip(
                        label: context.tr(
                          _showEvents ? 'filter.done' : 'filter.paid',
                        ),
                        selected: _filter == SubscriptionStatus.paid,
                        onTap: () =>
                            setState(() => _filter = SubscriptionStatus.paid),
                      ),
                      _FilterChip(
                        label: context.tr('filter.dueSoon'),
                        selected: _filter == SubscriptionStatus.dueSoon,
                        onTap: () => setState(
                          () => _filter == SubscriptionStatus.dueSoon,
                        ),
                      ),
                      _FilterChip(
                        label: context.tr('filter.overdue'),
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
                  SubscriptionsLoading() ||
                  SubscriptionsInitial() => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: SkeletonListView(),
                  ),
                  SubscriptionsError(:final message) => EmptyState(
                    icon: LucideIcons.cloudOff,
                    title: context.tr('common.loadError'),
                    subtitle: message,
                    action: FilledButton.tonalIcon(
                      onPressed: () =>
                          context.read<SubscriptionsCubit>().refresh(),
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      label: Text(context.tr('common.retry')),
                    ),
                  ),
                  SubscriptionsLoaded(:final items) => _buildList(
                    context,
                    items,
                  ),
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
      // Onglet courant : abonnements ou rendez-vous, jamais les deux.
      if (s.isEvent != _showEvents) return false;
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
        title: context.tr('subs.empty'),
        subtitle: context.tr('subs.emptySub'),
        action: FilledButton.icon(
          onPressed: () => _showAddSheet(context),
          icon: const Icon(LucideIcons.plus, size: 18),
          label: Text(context.tr('subs.addFirst')),
        ),
      );
    }
    if (filtered.isEmpty) {
      // Onglet vide sans recherche → invite à créer ce type
      // d'élément plutôt qu'un « aucun résultat » trompeur.
      final noItemsOfType = items.every((s) => s.isEvent != _showEvents);
      if (noItemsOfType && q.isEmpty && _filter == null) {
        return EmptyState(
          icon: _showEvents ? LucideIcons.calendarClock : LucideIcons.repeat,
          title: context.tr(
            _showEvents ? 'subs.emptyEvents' : 'subs.emptySubs',
          ),
          action: FilledButton.icon(
            onPressed: () => _showAddSheet(context),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: Text(context.tr('common.add')),
          ),
        );
      }
      return EmptyState(
        icon: LucideIcons.searchX,
        title: context.tr('subs.noResult'),
        subtitle: context.tr('subs.noResultSub'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<SubscriptionsCubit>().refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 96 + AppShell.barInset),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => AnimatedFadeIn(
          delay: Duration(milliseconds: 40 * index.clamp(0, 8)),
          child: SubscriptionTile(
            subscription: filtered[index],
            onMarkPaid: () => _markPaid(context, filtered[index]),
            onTap: () =>
                context.push(AppRoutes.subscriptionDetail(filtered[index].id)),
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
        Ok() => context.tr(sub.isEvent ? 'toast.done' : 'toast.paid', {
          'name': sub.name,
        }),
        Err(failure: final f) => f.localizedMessage,
      }),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void _showAddSheet(BuildContext context) =>
      showSubscriptionFormSheet(context, isEvent: _showEvents);
}

/// Ouvre le formulaire d'ajout/édition d'abonnement.
/// Réutilisé par la page détail (bouton Modifier) : passer
/// [existing] pour éditer, rien pour créer. [isEvent] pré-sélectionne
/// le type rendez-vous (ajout depuis l'onglet Rendez-vous).
void showSubscriptionFormSheet(
  BuildContext context, {
  Subscription? existing,
  bool isEvent = false,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Le sheet recouvre tout l'écran, y compris la pill de
    // navigation — sinon elle passerait par-dessus le bouton
    // de validation depuis extendBody.
    useRootNavigator: true,
    builder: (_) => BlocProvider.value(
      value: context.read<SubscriptionsCubit>(),
      child: _AddSubscriptionSheet(existing: existing, isEvent: isEvent),
    ),
  );
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

/// Formulaire d'ajout/édition en bottom sheet — validé localement,
/// envoyé au SubscriptionsCubit. [existing] non null = édition.
class _AddSubscriptionSheet extends StatefulWidget {
  const _AddSubscriptionSheet({this.existing, this.isEvent = false});

  final Subscription? existing;

  /// Pré-sélection « Rendez-vous » quand on ajoute depuis
  /// l'onglet dédié — l'utilisateur peut toujours basculer.
  final bool isEvent;

  @override
  State<_AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends State<_AddSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _provider = TextEditingController();
  final _amount = TextEditingController();
  // Note libre : ville, lieu, référence — rappelée dans les
  // alertes et notifications d'échéance.
  final _description = TextEditingController();
  SubscriptionCategory _category = SubscriptionCategory.software;
  BillingCycle _cycle = BillingCycle.monthly;
  // Mode rendez-vous/événement : pas de fournisseur ni de
  // montant — l'app sert juste à ne pas rater l'échéance.
  bool _isEvent = false;
  // Devise de l'abonnement — pré-remplie avec la devise principale
  // du workspace, modifiable (un compte peut suivre EUR + FCFA).
  String _currency = 'XAF';
  // Pays où l'abonnement est actif — choisi par l'utilisateur
  // (peut différer du pays du workspace ET du siège du
  // fournisseur, ex. un serveur loué en Allemagne).
  String _country = '';
  // Suggestions de fournisseurs selon le pays du workspace.
  List<Map<String, dynamic>> _providerSuggestions = [];
  bool _loadingProviders = true;
  bool _providerLoadFailed = false;
  // Date de la PREMIÈRE échéance — aujourd'hui par défaut. Elle
  // peut être dans le passé (ex. serveur loué dimanche, saisi
  // mercredi) : la prochaine échéance est alors calculée auto.
  DateTime _firstDue = DateTime.now();
  // Heure du rendez-vous — null = journée entière.
  TimeOfDay? _dueTime;
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
    _country = workspace?.country ?? '';
    // Ajout depuis l'onglet Rendez-vous : type déjà choisi.
    if (widget.isEvent && widget.existing == null) {
      _isEvent = true;
      _cycle = BillingCycle.once;
    }
    // Mode édition : on pré-remplit tous les champs.
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _provider.text = e.provider;
      _description.text = e.description;
      _amount.text = e.amount == e.amount.roundToDouble()
          ? e.amount.toStringAsFixed(0)
          : e.amount.toString();
      _category = e.category;
      _cycle = e.cycle;
      _currency = e.currency;
      if (e.country.isNotEmpty) _country = e.country;
      _isEvent = e.category == SubscriptionCategory.event;
      _firstDue = e.nextDueDate;
      _dueTime = e.dueTime;
      _startDate = e.startDate;
      _endDate = e.endDate;
    }
    // Fournisseurs connus du pays → autocomplétion du champ.
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loadingProviders = true;
      _providerLoadFailed = false;
    });
    try {
      final list = await getIt<WorkspaceRemoteDataSource>().providerCatalog();
      if (mounted) setState(() => _providerSuggestions = list);
    } catch (_) {
      if (mounted) setState(() => _providerLoadFailed = true);
    } finally {
      if (mounted) setState(() => _loadingProviders = false);
    }
  }

  /// Devises proposées : principale + secondaires du workspace en
  /// premier, puis toutes les devises couvertes par les pays
  /// supportés — un abonnement peut être facturé dans n'importe
  /// quelle monnaie (Netflix en USD, loyer en XAF, fibre en EUR).
  List<String> get _currencies {
    final workspace = switch (context.read<AuthCubit>().state) {
      Authenticated(user: final u) => u.workspace,
      _ => null,
    };
    final preferred = <String>{
      if (workspace?.defaultCurrency?.isNotEmpty ?? false)
        workspace!.defaultCurrency!,
      ...?workspace?.extraCurrencies,
      'XAF',
      'EUR',
      'USD',
    }.toList();
    final rest = AppCountries.all
        .map((c) => c.currency)
        .toSet()
        .difference(preferred.toSet())
        .toList()
      ..sort();
    return [...preferred, ...rest];
  }

  @override
  void dispose() {
    _name.dispose();
    _provider.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Prochaine échéance réelle : on avance la première échéance
  /// cycle par cycle jusqu'à une date >= aujourd'hui.
  DateTime get _nextDue {
    var d = _firstDue;
    final today = DateUtils.dateOnly(DateTime.now());
    var guard = 0;
    // 800 itérations : couvre ~2 ans pour un cycle quotidien
    // sur une première échéance très ancienne.
    while (d.isBefore(today) && guard++ < 800) {
      d = switch (_cycle) {
        BillingCycle.monthly => DateTime(d.year, d.month + 1, d.day),
        BillingCycle.quarterly => DateTime(d.year, d.month + 3, d.day),
        BillingCycle.yearly => DateTime(d.year + 1, d.month, d.day),
        BillingCycle.daily => d.add(const Duration(days: 1)),
        BillingCycle.weekly => d.add(const Duration(days: 7)),
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
      helpText: context.tr('form.pickStart'),
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
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
      helpText: context.tr('form.pickEnd'),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDue,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: context.tr('form.pickFirstDue'),
    );
    if (picked != null) setState(() => _firstDue = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: context.tr('form.pickTime'),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    final amount = _isEvent
        ? 0.0
        : double.tryParse(
                _amount.text.replaceAll(' ', '').replaceAll(',', '.'),
              ) ??
              0;
    final cubit = context.read<SubscriptionsCubit>();
    final existing = widget.existing;
    final result = existing == null
        ? await cubit.create(
            name: _name.text.trim(),
            provider: _isEvent ? '' : _provider.text.trim(),
            category: _isEvent ? SubscriptionCategory.event : _category,
            amount: amount,
            nextDueDate: _isEvent ? _firstDue : _nextDue,
            cycle: _cycle,
            currency: _currency,
            description: _description.text.trim(),
            country: _country,
            startDate: _isEvent ? null : _startDate,
            endDate: _isEvent ? null : _endDate,
            dueTime: _isEvent ? _dueTime : null,
          )
        : await cubit.update(
            id: existing.id,
            name: _name.text.trim(),
            provider: _isEvent ? '' : _provider.text.trim(),
            category: _isEvent ? SubscriptionCategory.event : _category,
            amount: amount,
            nextDueDate: _isEvent ? _firstDue : _nextDue,
            cycle: _cycle,
            currency: _currency,
            description: _description.text.trim(),
            country: _country,
            clearStartDate: _isEvent || _startDate == null,
            startDate: _startDate,
            clearEndDate: _isEvent || _endDate == null,
            endDate: _endDate,
            clearDueTime: !_isEvent || _dueTime == null,
            dueTime: _dueTime,
          );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result is Ok) {
      Navigator.of(context).pop();
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.flat,
        title: Text(
          widget.existing != null
              ? context.tr('form.saved')
              : _isEvent
              ? context.tr('form.eventSaved')
              : context.tr('form.subSaved'),
        ),
        autoCloseDuration: const Duration(seconds: 3),
      );
    } else if (result case Err(failure: final f)) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.flat,
        title: Text(f.localizedMessage),
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
                widget.existing != null
                    ? context.tr('form.editTitle', {
                        'name': widget.existing!.name,
                      })
                    : _isEvent
                    ? context.tr('form.newEvent')
                    : context.tr('form.newSub'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              // Type d'entrée — un abonnement facturé ou un simple
              // rappel d'échéance (entretien, événement, RDV…).
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(LucideIcons.repeat, size: 17),
                    label: Text(context.tr('form.typeSub')),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(LucideIcons.calendarClock, size: 17),
                    label: Text(context.tr('form.typeEvent')),
                  ),
                ],
                selected: {_isEvent},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _isEvent = s.first;
                  // Bascule vers RDV : récurrence « une fois » par
                  // défaut (l'utilisateur la change ensuite). Retour
                  // abonnement : mensuel si on venait de « une fois ».
                  if (_isEvent && widget.existing == null) {
                    _cycle = BillingCycle.once;
                  } else if (!_isEvent && _cycle == BillingCycle.once) {
                    _cycle = BillingCycle.monthly;
                  }
                }),
              ),
              // Raccourci vers l'ajout automatique : connexion à un
              // compte fournisseur ou services populaires pré-remplis —
              // importe plusieurs abonnements d'un coup.
              if (widget.existing == null && !_isEvent)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      router.push(AppRoutes.integrations);
                    },
                    icon: const Icon(LucideIcons.sparkles, size: 17),
                    label: Text(context.tr('form.import')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: _isEvent
                      ? context.tr('form.title')
                      : context.tr('form.name'),
                  hintText: _isEvent
                      ? context.tr('form.titleHint')
                      : context.tr('form.nameHint'),
                  prefixIcon: const Icon(LucideIcons.tag, size: 20),
                ),
                validator: _required,
              ),
              const SizedBox(height: 14),
              // Fournisseur (optionnel) avec suggestions adaptées au
              // pays (ENEO/Camwater pour le Cameroun, EDF/Orange…).
              if (!_isEvent) ...[
                DropdownMenu<String>(
                  controller: _provider,
                  expandedInsets: EdgeInsets.zero,
                  enableFilter: true,
                  enableSearch: true,
                  requestFocusOnTap: true,
                  menuHeight: 260,
                  label: Text(context.tr('form.provider')),
                  hintText: context.tr('form.providerHint'),
                  leadingIcon: const Icon(LucideIcons.building2, size: 20),
                  helperText: _loadingProviders
                      ? context.tr('form.providerLoading')
                      : context.tr('form.providerHelper'),
                  dropdownMenuEntries: [
                    // Drapeau du pays du fournisseur devant le nom.
                    for (final p in {
                      for (final p in _providerSuggestions)
                        p['name'] as String: p,
                    }.values)
                      DropdownMenuEntry(
                        value: p['name'] as String,
                        label: p['name'] as String,
                        leadingIcon: Text(
                          (p['flag'] as String?)?.isNotEmpty == true
                              ? p['flag'] as String
                              : '🌐',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                  ],
                  onSelected: (name) {
                    if (name == null) return;
                    final option = _providerSuggestions.firstWhere(
                      (p) => p['name'] == name,
                    );
                    setState(() {
                      _category = SubscriptionCategory.parse(
                        option['category'] as String? ?? 'other',
                      );
                      if (_name.text.trim().isEmpty) _name.text = name;
                    });
                  },
                ),
                if (_providerLoadFailed)
                  TextButton.icon(
                    onPressed: _loadProviders,
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: Text(context.tr('form.providerFail')),
                  ),
              ],
              const SizedBox(height: 14),
              // Description : ville/lieu du service ou détail du
              // rendez-vous — affichée dans les alertes.
              TextFormField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: context.tr('form.description'),
                  hintText: _isEvent
                      ? context.tr('form.descHintEvent')
                      : context.tr('form.descHint'),
                  prefixIcon: const Icon(LucideIcons.mapPin, size: 20),
                ),
                maxLength: 255,
                maxLines: 1,
              ),
              if (!_isEvent) const SizedBox(height: 14),
              if (!_isEvent)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _amount,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('common.amount'),
                          prefixIcon: const Icon(
                            LucideIcons.banknote,
                            size: 20,
                          ),
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
                              onChanged: (v) => setState(() => _currency = v!),
                            ),
                          ),
                        ),
                        validator: (v) =>
                            (double.tryParse(
                                      (v ?? '')
                                          .replaceAll(' ', '')
                                          .replaceAll(',', '.'),
                                    ) ??
                                    0) >
                                0
                            ? null
                            : context.tr('form.amountInvalid'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<BillingCycle>(
                        initialValue: _cycle,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.tr('form.cycle'),
                        ),
                        items: BillingCycle.values
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  context.tr('cycle.${c.name}'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
              if (!_isEvent)
                DropdownButtonFormField<SubscriptionCategory>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('form.category'),
                    prefixIcon: const Icon(LucideIcons.layoutGrid, size: 20),
                  ),
                  items: SubscriptionCategory.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Icon(c.icon, size: 18, color: c.color),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  c.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (c) => setState(() => _category = c!),
                ),
              if (!_isEvent) const SizedBox(height: 14),
              // Pays où l'abonnement est actif — n'importe lequel,
              // indépendant du pays du compte ou du fournisseur.
              if (!_isEvent)
                DropdownButtonFormField<String>(
                  initialValue: _country.isEmpty ? null : _country,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('form.country'),
                    prefixIcon: const Icon(LucideIcons.globe, size: 20),
                  ),
                  items: AppCountries.all
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.code,
                          child: Row(
                            children: [
                              Text(c.flag),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  c.nameFor(AppFormatters.lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _country = v ?? ''),
                ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(LucideIcons.calendar, size: 18),
                label: Text(
                  _isEvent
                      ? context.tr('form.date', {
                          'date': AppFormatters.dateLong(_firstDue),
                        })
                      : context.tr('form.firstDue', {
                          'date': AppFormatters.dateLong(_firstDue),
                        }),
                ),
              ),
              // Heure du rendez-vous — optionnelle, effaçable.
              if (_isEvent) const SizedBox(height: 8),
              if (_isEvent)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(LucideIcons.clock, size: 18),
                        label: Text(
                          _dueTime == null
                              ? context.tr('form.time')
                              : context.tr('form.timeSet', {
                                  'time': AppFormatters.time(
                                    _dueTime!.hour,
                                    _dueTime!.minute,
                                  ),
                                }),
                        ),
                      ),
                    ),
                    if (_dueTime != null)
                      IconButton(
                        tooltip: context.tr('form.noTime'),
                        onPressed: () => setState(() => _dueTime = null),
                        icon: const Icon(LucideIcons.x, size: 18),
                      ),
                  ],
                ),
              // Récurrence du rendez-vous : une fois, chaque jour à
              // la même heure, chaque semaine (même jour/heure),
              // chaque mois ou chaque année. Le backend fait avancer
              // l'échéance à chaque « Terminé ».
              if (_isEvent) const SizedBox(height: 8),
              if (_isEvent)
                DropdownButtonFormField<BillingCycle>(
                  initialValue: _cycle,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('form.recurrence'),
                    prefixIcon: const Icon(LucideIcons.repeat, size: 18),
                  ),
                  items:
                      const [
                            BillingCycle.once,
                            BillingCycle.daily,
                            BillingCycle.weekly,
                            BillingCycle.monthly,
                            BillingCycle.yearly,
                          ]
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(context.tr('cycle.${c.name}')),
                            ),
                          )
                          .toList(),
                  onChanged: (c) => setState(() => _cycle = c!),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _isEvent ? LucideIcons.bellRing : LucideIcons.info,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _isEvent
                          ? context.tr('form.reminderInfo')
                          : _cycle == BillingCycle.once
                          ? context.tr('form.onceDue', {
                              'date': AppFormatters.dateLong(_firstDue),
                            })
                          : context.tr('form.nextDue', {
                              'date': AppFormatters.dateLong(_nextDue),
                            }),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Dates optionnelles regroupées dans une section
              // pliable — le formulaire reste simple par défaut.
              if (!_isEvent)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  leading: Icon(
                    LucideIcons.settings2,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    context.tr('form.advanced'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    context.tr('form.advancedSub'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  children: [
                    // Date de prise réelle — peut être inconnue.
                    OutlinedButton.icon(
                      onPressed: _pickStartDate,
                      icon: const Icon(LucideIcons.calendarPlus, size: 18),
                      label: Text(
                        _startDate == null
                            ? context.tr('form.startDate')
                            : context.tr('form.started', {
                                'date': AppFormatters.dateLong(_startDate!),
                              }),
                      ),
                    ),
                    if (_startDate != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() => _startDate = null),
                          child: Text(context.tr('form.unknownDate')),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Fin de contrat — CDD, engagement limité…
                    OutlinedButton.icon(
                      onPressed: _pickEndDate,
                      icon: const Icon(LucideIcons.calendarOff, size: 18),
                      label: Text(
                        _endDate == null
                            ? context.tr('form.endDate')
                            : context.tr('form.ends', {
                                'date': AppFormatters.dateLong(_endDate!),
                              }),
                      ),
                    ),
                    if (_endDate != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() => _endDate = null),
                          child: Text(context.tr('form.noEnd')),
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
                label: Text(
                  _submitting
                      ? context.tr('form.submitting')
                      : widget.existing != null
                      ? context.tr('form.saveChanges')
                      : _isEvent
                      ? context.tr('form.createReminder')
                      : context.tr('form.add'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? context.tr('common.required') : null;
}
