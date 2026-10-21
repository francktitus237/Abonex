import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../subscriptions/domain/entities/subscription.dart';
import '../../../subscriptions/presentation/cubit/subscriptions_cubit.dart';
import '../../data/datasources/workspace_remote_datasource.dart';

/// Import en masse et connexions aux comptes externes.
/// Réponse à la demande client : éviter la saisie manuelle —
/// import CSV/Excel ou synchronisation OVH/IONOS.
class IntegrationsPage extends StatefulWidget {
  const IntegrationsPage({super.key});

  @override
  State<IntegrationsPage> createState() => _IntegrationsPageState();
}

class _IntegrationsPageState extends State<IntegrationsPage> {
  final _datasource = getIt<WorkspaceRemoteDataSource>();

  List<Map<String, dynamic>> _connectors = [];
  List<Map<String, dynamic>> _detected = [];
  // Services populaires (Spotify, Netflix…) : pas d'API de
  // facturation chez eux — on pré-remplit forfait et catégorie,
  // l'utilisateur pose juste la date.
  List<Map<String, dynamic>> _presets = [];
  // Comptes externes déjà connectés (credentials chiffrés côté
  // serveur) — re-synchronisation en un tap.
  List<Map<String, dynamic>> _connections = [];
  String _presetQuery = '';
  bool _loadingConnectors = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadConnectors();
    _loadPresets();
    _loadConnections();
  }

  Future<void> _loadConnectors() async {
    try {
      final list = await _datasource.connectors();
      if (mounted) setState(() => _connectors = list);
    } catch (_) {
      // Catalogue indisponible : la page reste utilisable pour le CSV.
    } finally {
      if (mounted) setState(() => _loadingConnectors = false);
    }
  }

  Future<void> _loadConnections() async {
    try {
      final list = await _datasource.connections();
      if (mounted) setState(() => _connections = list);
    } catch (_) {}
  }

  /// Re-synchronise un compte déjà connecté — pas besoin de
  /// resaisir les identifiants.
  Future<void> _resync(Map<String, dynamic> conn) async {
    setState(() => _busy = true);
    try {
      final detected =
          await _datasource.resyncConnection(conn['id'] as int);
      if (!mounted) return;
      if (detected.isEmpty) {
        _toast('Aucun service détecté sur ce compte.');
      } else {
        setState(() => _detected = detected);
      }
    } on Exception {
      if (mounted) {
        _toast('Synchronisation impossible.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect(Map<String, dynamic> conn) async {
    setState(() => _busy = true);
    try {
      await _datasource.disconnectConnection(conn['id'] as int);
      if (!mounted) return;
      setState(
        () => _connections.removeWhere((c) => c['id'] == conn['id']),
      );
      _toast('${conn['provider_label']} déconnecté.');
    } on Exception {
      if (mounted) _toast('Déconnexion impossible.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadPresets() async {
    try {
      final list = await _datasource.providerCatalog();
      if (mounted) {
        setState(
          () => _presets = list
              .where((p) => (p['plans'] as List?)?.isNotEmpty ?? false)
              .toList(),
        );
      }
    } catch (_) {}
  }

  // ---------- Import CSV ----------

  /// Colonnes attendues (1re ligne d'en-tête) :
  /// name, provider, category, amount, currency, cycle, next_due_date
  Future<void> _importCsv() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (picked.isEmpty || !mounted) return;
    final defaultCurrency = switch (context.read<AuthCubit>().state) {
      Authenticated(user: final user) => user.workspace?.defaultCurrency ?? 'XAF',
      _ => 'XAF',
    };
    setState(() => _busy = true);
    try {
      final bytes = await picked.first.readAsBytes();
      final content = utf8.decode(bytes);
      final rows = const CsvDecoder().convert(content);
      if (rows.length < 2) {
        _toast('Fichier vide ou en-têtes manquants.', error: true);
        return;
      }
      final headers =
          rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
      final items = <Map<String, dynamic>>[];
      for (final row in rows.skip(1)) {
        final map = <String, dynamic>{};
        for (var i = 0; i < headers.length && i < row.length; i++) {
          map[headers[i]] = row[i]?.toString().trim();
        }
        if ((map['name'] ?? '').isEmpty) continue;
        items.add({
          'name': map['name'],
          'provider': map['provider'] ?? '',
          'category': map['category'] ?? 'other',
          'amount': map['amount'] ?? '0',
          'currency': (map['currency'] ?? '').isEmpty
              ? defaultCurrency
              : map['currency'],
          'cycle': map['cycle'] ?? 'monthly',
          'next_due_date': map['next_due_date'],
        });
      }
      if (items.isEmpty) {
        _toast('Aucune ligne valide dans le fichier.', error: true);
        return;
      }
      final result = await _datasource.bulkCreate(items);
      if (!mounted) return;
      _toast(
        '${result['created']} abonnement(s) importé(s)'
        '${(result['errors'] as List).isNotEmpty ? ' — ${(result['errors'] as List).length} ligne(s) ignorée(s)' : ''}.',
      );
      if (mounted) {
        await context.read<SubscriptionsCubit>().refresh();
      }
    } on Exception {
      if (mounted) _toast('Fichier illisible. Vérifiez le format CSV.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- Connecteurs externes ----------

  Future<void> _connect(Map<String, dynamic> connector) async {
    final fields =
        (connector['auth_fields'] as List).cast<Map<String, dynamic>>();
    final controllers = {
      for (final f in fields) f['key'] as String: TextEditingController(
        text: f['default']?.toString() ?? '',
      ),
    };
    final formKey = GlobalKey<FormState>();

    final credentials = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Connecter ${connector['label']}',
                  style: Theme.of(ctx).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  connector['description'] as String? ?? '',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final f in fields) ...[
                  TextFormField(
                    controller: controllers[f['key']],
                    obscureText: f['secret'] == true,
                    decoration: InputDecoration(
                      labelText: f['label'] as String,
                      prefixIcon:
                          const Icon(LucideIcons.keyRound, size: 18),
                    ),
                    validator: (v) => (f['secret'] == true &&
                            (v == null || v.trim().isEmpty))
                        ? 'Requis'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.of(ctx).pop({
                        for (final e in controllers.entries)
                          e.key: e.value.text.trim(),
                      });
                    }
                  },
                  icon: const Icon(LucideIcons.plug, size: 18),
                  label: const Text('Connecter et analyser'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    for (final c in controllers.values) {
      c.dispose();
    }
    if (credentials == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final detected = await _datasource.syncConnector(
        connector['slug'] as String,
        credentials,
      );
      if (!mounted) return;
      if (detected.isEmpty) {
        _toast('Aucun service détecté sur ce compte.');
      } else {
        setState(() => _detected = detected);
      }
      await _loadConnections();
    } on Exception {
      if (mounted) {
        _toast('Connexion au fournisseur impossible.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importDetected() async {
    setState(() => _busy = true);
    try {
      final result = await _datasource.bulkCreate(_detected);
      if (!mounted) return;
      setState(() => _detected = []);
      _toast('${result['created']} abonnement(s) importé(s).');
      await context.read<SubscriptionsCubit>().refresh();
    } on Exception {
      if (mounted) _toast('Import impossible. Réessayez.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Création rapide depuis un preset : forfait, montant et cycle
  /// déjà remplis — il ne reste que la date de renouvellement.
  Future<void> _quickAddPreset(Map<String, dynamic> preset) async {
    final workspace = switch (context.read<AuthCubit>().state) {
      Authenticated(user: final u) => u.workspace,
      _ => null,
    };
    final currencies = <String>{
      if (workspace?.defaultCurrency?.isNotEmpty ?? false)
        workspace!.defaultCurrency!,
      ...?workspace?.extraCurrencies,
      'XAF', 'EUR', 'USD',
    }.toList();

    final entry = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _PresetSheet(preset: preset, currencies: currencies),
    );
    if (entry == null || !mounted) return;

    setState(() => _busy = true);
    final result = await context.read<SubscriptionsCubit>().create(
          name: preset['name'] as String,
          provider: preset['name'] as String,
          category: SubscriptionCategory.parse(preset['category'] as String? ?? ''),
          amount: entry['amount'] as double,
          nextDueDate: entry['date'] as DateTime,
          cycle: entry['cycle'] as BillingCycle,
          currency: entry['currency'] as String,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(
      switch (result) {
        Ok() => '${preset['name']} ajouté à vos abonnements.',
        Err(failure: final f) => f.message,
      },
      error: result is Err,
    );
  }

  /// Connecteurs regroupés par domaine, dans l'ordre d'affichage.
  List<(String, List<Map<String, dynamic>>, String)> _connectorGroups() {
    const order = ['payments', 'cloud', 'domains', 'other'];
    // Les connecteurs OAuth (banque) ont leur propre carte dédiée.
    final formConnectors =
        _connectors.where((c) => c['oauth'] != true).toList();
    const titles = {
      'payments': 'Paiements récurrents',
      'cloud': 'Cloud, serveurs & SaaS',
      'domains': 'Domaines & registrars',
      'other': 'Autres',
    };
    return [
      for (final g in order)
        if (formConnectors.any((c) => c['group'] == g))
          (titles[g]!,
              formConnectors.where((c) => c['group'] == g).toList(), g),
    ];
  }

  IconData _groupIcon(String group) => switch (group) {
    'payments' => LucideIcons.creditCard,
    'domains' => LucideIcons.globe,
    'cloud' => LucideIcons.server,
    _ => LucideIcons.plugZap,
  };

  /// Services populaires regroupés par univers — demande client :
  /// classer et présenter par catégorie plutôt qu'une liste plate.
  List<(String, List<Map<String, dynamic>>)> _presetGroups() {
    const order = [
      'streaming', 'music', 'storage', 'gaming',
      'productivity', 'security', 'other',
    ];
    const titles = {
      'streaming': 'Streaming & TV',
      'music': 'Musique',
      'storage': 'Stockage cloud',
      'gaming': 'Jeux vidéo',
      'productivity': 'Productivité & outils pro',
      'security': 'Sécurité & VPN',
      'other': 'Autres',
    };
    final filtered = _presets
        .where(
          (p) => _presetQuery.isEmpty ||
              (p['name'] as String).toLowerCase().contains(_presetQuery),
        )
        .toList();
    return [
      for (final g in order)
        if (filtered.any((p) => (p['group'] ?? 'other') == g))
          (
            titles[g]!,
            filtered.where((p) => (p['group'] ?? 'other') == g).toList(),
          ),
    ];
  }

  void _toast(String message, {bool error = false}) {
    toastification.show(
      context: context,
      type: error ? ToastificationType.error : ToastificationType.success,
      style: ToastificationStyle.flat,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Import & intégrations')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // --- Import fichier ---
          _SectionCard(
            icon: LucideIcons.fileUp,
            title: 'Importer un fichier',
            subtitle:
                'CSV avec les colonnes : name, provider, category, '
                'amount, currency, cycle, next_due_date',
            child: FilledButton.tonalIcon(
              onPressed: _busy ? null : _importCsv,
              icon: const Icon(LucideIcons.upload, size: 18),
              label: const Text('Choisir un fichier CSV'),
            ),
          ),
          const SizedBox(height: 16),

          // --- Comptes déjà connectés ---
          if (_connections.isNotEmpty)
            _SectionCard(
              icon: LucideIcons.link2,
              title: 'Comptes connectés',
              subtitle:
                  'Re-synchronisez en un tap — vos identifiants '
                  'restent chiffrés côté serveur.',
              child: Column(
                children: [
                  for (final conn in _connections)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            scheme.primary.withValues(alpha: 0.12),
                        child: Icon(LucideIcons.plugZap,
                            size: 18, color: scheme.primary),
                      ),
                      title: Text(
                        '${conn['provider_label']} — ${conn['label']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Re-synchroniser',
                            onPressed:
                                _busy ? null : () => _resync(conn),
                            icon: const Icon(
                              LucideIcons.refreshCw,
                              size: 18,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Déconnecter',
                            onPressed:
                                _busy ? null : () => _disconnect(conn),
                            icon: Icon(
                              LucideIcons.unlink,
                              size: 18,
                              color: scheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (_connections.isNotEmpty) const SizedBox(height: 16),

          // --- Connecteurs ---
          _SectionCard(
            icon: LucideIcons.plugZap,
            title: 'Connexions professionnelles',
            subtitle:
                'Ces intégrations nécessitent des clés API du fournisseur, '
                'pas votre mot de passe habituel. Les données disponibles '
                'varient selon le service ; certains montants et dates '
                'restent à compléter. Les connecteurs de paiement '
                'concernent les abonnements facturés à vos clients.',
            child: _loadingConnectors
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      for (final group in _connectorGroups()) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              group.$1,
                              style:
                                  theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        for (final c in group.$2)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor:
                                  scheme.primary.withValues(alpha: 0.12),
                              child: Icon(
                                _groupIcon(group.$3),
                                size: 18,
                                color: scheme.primary,
                              ),
                            ),
                            title: Text(c['label'] as String),
                            subtitle: Text(
                              c['description'] as String? ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: FilledButton.tonal(
                              onPressed:
                                  _busy ? null : () => _connect(c),
                              child: const Text('Connecter'),
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // --- Services populaires (pré-remplis) ---
          if (_presets.isNotEmpty)
            _SectionCard(
              icon: LucideIcons.sparkles,
              title: 'Services populaires',
              subtitle:
                  'Netflix, Spotify & co ne publient pas de date de '
                  'prélèvement via API — choisissez le service, tout est '
                  'pré-rempli, vous posez juste la date de renouvellement.',
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) =>
                        setState(() => _presetQuery = v.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un service…',
                      prefixIcon: Icon(LucideIcons.search, size: 18),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final group in _presetGroups()) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          group.$1,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    for (final p in group.$2)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: CircleAvatar(
                          radius: 15,
                          backgroundColor:
                              scheme.primary.withValues(alpha: 0.10),
                          child: const Icon(LucideIcons.badgePlus, size: 16),
                        ),
                        title: Text(p['name'] as String),
                        subtitle: Text(
                          (p['plans'] as List)
                              .map((pl) => pl['label'])
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: _busy ? null : () => _quickAddPreset(p),
                      ),
                  ],
                ],
              ),
            ),

          // --- Abonnements détectés ---
          if (_detected.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              icon: LucideIcons.listChecks,
              title: '${_detected.length} service(s) détecté(s)',
              subtitle:
                  'Vérifiez puis importez — le montant reste à '
                  'compléter si le fournisseur ne le publie pas.',
              child: Column(
                children: [
                  for (final s in _detected.take(10))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(LucideIcons.server, size: 16),
                      title: Text(s['name']?.toString() ?? ''),
                      subtitle: Text(
                        '${s['provider'] ?? ''} · ${s['cycle'] ?? ''} · '
                        'échéance : ${s['next_due_date'] ?? 'à définir'}',
                      ),
                    ),
                  if (_detected.length > 10)
                    Text('… et ${_detected.length - 10} autre(s)',
                        style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _importDetected,
                    icon: const Icon(LucideIcons.download, size: 18),
                    label:
                        Text('Importer ${_detected.length} abonnement(s)'),
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

/// Ajout rapide d'un service connu : forfait (montant/cycle
/// pré-remplis) + date de prochain renouvellement.
class _PresetSheet extends StatefulWidget {
  const _PresetSheet({required this.preset, required this.currencies});

  final Map<String, dynamic> preset;
  final List<String> currencies;

  @override
  State<_PresetSheet> createState() => _PresetSheetState();
}

class _PresetSheetState extends State<_PresetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  int _planIndex = 0;
  String _currency = 'EUR';
  BillingCycle _cycle = BillingCycle.monthly;
  DateTime _date = DateTime.now().add(const Duration(days: 30));

  List<Map<String, dynamic>> get _plans =>
      (widget.preset['plans'] as List).cast<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    final plan = _plans.first;
    _currency = plan['currency'] as String? ?? 'EUR';
    _cycle = plan['cycle'] == 'yearly'
        ? BillingCycle.yearly
        : plan['cycle'] == 'quarterly'
            ? BillingCycle.quarterly
            : BillingCycle.monthly;
    _amount = TextEditingController(
      text: (plan['amount'] as num).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _applyPlan(int i) {
    final plan = _plans[i];
    setState(() {
      _planIndex = i;
      _amount.text = (plan['amount'] as num).toStringAsFixed(2);
      _currency = plan['currency'] as String? ?? _currency;
      _cycle = switch (plan['cycle']) {
        'yearly' => BillingCycle.yearly,
        'quarterly' => BillingCycle.quarterly,
        _ => BillingCycle.monthly,
      };
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Prochain renouvellement',
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(
          _amount.text.replaceAll(' ', '').replaceAll(',', '.'),
        ) ??
        0;
    Navigator.of(context).pop({
      'amount': amount,
      'currency': _currency,
      'cycle': _cycle,
      'date': _date,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ajouter ${widget.preset['name']}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Montant et cycle pré-remplis — ajustez si votre forfait '
              'diffère, puis indiquez la date du prochain prélèvement.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _plans.length; i++)
                  ChoiceChip(
                    label: Text(
                      '${_plans[i]['label']} — '
                      '${AppFormatters.money(
                        (_plans[i]['amount'] as num).toDouble(),
                        _plans[i]['currency'] as String? ?? 'EUR',
                      )}',
                    ),
                    selected: i == _planIndex,
                    showCheckmark: false,
                    onSelected: (_) => _applyPlan(i),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Montant',
                      prefixIcon:
                          const Icon(LucideIcons.banknote, size: 20),
                      suffixIcon: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: widget.currencies.contains(_currency)
                              ? _currency
                              : widget.currencies.first,
                          items: widget.currencies
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
                    validator: (v) => (double.tryParse(
                              (v ?? '')
                                  .replaceAll(' ', '')
                                  .replaceAll(',', '.'),
                            ) ??
                            0) >
                        0
                        ? null
                        : 'Montant invalide',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<BillingCycle>(
                    initialValue: _cycle,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Cycle'),
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
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(LucideIcons.calendar, size: 18),
              label: Text(
                'Prochain prélèvement : ${AppFormatters.dateLong(_date)}',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _confirm,
              icon: const Icon(LucideIcons.plus, size: 19),
              label: const Text('Ajouter à mes abonnements'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary
                      .withValues(alpha: 0.12),
                  child: Icon(icon, size: 18,
                      color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
