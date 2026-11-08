import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/datasources/workspace_remote_datasource.dart';

/// Pilotage & budgets (étude §B) : départements / centres de
/// coûts + budgets par poste avec usage réel calculé par
/// /insights/ (alertes seuil et dépassement).
class GovernancePage extends StatefulWidget {
  const GovernancePage({super.key});

  @override
  State<GovernancePage> createState() => _GovernancePageState();
}

class _GovernancePageState extends State<GovernancePage> {
  List<Map<String, dynamic>>? _departments;
  List<Map<String, dynamic>>? _budgets;
  // Usage par budget id (via /insights/ → budgets[]).
  Map<int, Map<String, dynamic>> _usage = {};
  // Réglages espace (seuil d'approbation notamment).
  Map<String, dynamic>? _threshold;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final ds = getIt<WorkspaceRemoteDataSource>();
      final results = await Future.wait([
        ds.departments(),
        ds.budgets(),
        ds.insights(),
        ds.workspaceInfo(),
      ]);
      if (!mounted) return;
      final usage = <int, Map<String, dynamic>>{};
      final insightBudgets =
          (results[2] as Map<String, dynamic>)['budgets'];
      if (insightBudgets is List) {
        for (final b in insightBudgets) {
          final map = Map<String, dynamic>.from(b as Map);
          usage[map['id'] as int? ?? -1] = map;
        }
      }
      setState(() {
        _departments = results[0] as List<Map<String, dynamic>>;
        _budgets = results[1] as List<Map<String, dynamic>>;
        _usage = usage;
        _threshold = results[3] as Map<String, dynamic>;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    toastification.show(
      context: context,
      type: error
          ? ToastificationType.error
          : ToastificationType.success,
      title: Text(msg),
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  Future<void> _addDepartment() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('gov.deptAdd')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: ctx.tr('gov.deptName'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.tr('common.save')),
          ),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty || !mounted) return;
    final okMsg = context.tr('gov.saved');
    final errMsg = context.tr('gov.error');
    try {
      await getIt<WorkspaceRemoteDataSource>().createDepartment(
        ctrl.text.trim(),
      );
      _toast(okMsg);
      unawaited(_load());
    } catch (_) {
      _toast(errMsg, error: true);
    }
  }

  Future<void> _deleteDepartment(int id) async {
    final okMsg = context.tr('gov.deleted');
    final errMsg = context.tr('gov.error');
    try {
      await getIt<WorkspaceRemoteDataSource>().deleteDepartment(id);
      _toast(okMsg);
      unawaited(_load());
    } catch (_) {
      _toast(errMsg, error: true);
    }
  }

  Future<void> _addBudget() async {
    final amount = TextEditingController();
    String scope = 'category';
    String category = 'software';
    int? deptId =
        _departments?.isNotEmpty == true
            ? _departments!.first['id'] as int
            : null;
    int threshold = 80;
    const categories = [
      'software', 'rent', 'insurance', 'telecom', 'energy',
      'water', 'payroll', 'transport', 'event', 'other',
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => AlertDialog(
          title: Text(ctx.tr('gov.budgetAdd')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'category',
                    label: Text(ctx.tr('gov.byCategory')),
                  ),
                  ButtonSegment(
                    value: 'department',
                    label: Text(ctx.tr('gov.byDept')),
                  ),
                ],
                selected: {scope},
                onSelectionChanged: (s) =>
                    setSheet(() => scope = s.first),
              ),
              const SizedBox(height: 12),
              if (scope == 'category')
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(
                        value: c,
                        child: Text(ctx.tr('category.$c')),
                      ),
                  ],
                  onChanged: (v) =>
                      setSheet(() => category = v ?? 'other'),
                )
              else
                DropdownButtonFormField<int>(
                  initialValue: deptId,
                  items: [
                    for (final d in _departments ?? [])
                      DropdownMenuItem(
                        value: d['id'] as int,
                        child: Text('${d['name']}'),
                      ),
                  ],
                  onChanged: (v) => setSheet(() => deptId = v),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                decoration: InputDecoration(
                  labelText: ctx.tr('gov.budgetAmount'),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: threshold,
                decoration: InputDecoration(
                  labelText: ctx.tr('gov.threshold'),
                ),
                items: const [
                  DropdownMenuItem(value: 50, child: Text('50 %')),
                  DropdownMenuItem(value: 80, child: Text('80 %')),
                  DropdownMenuItem(value: 90, child: Text('90 %')),
                ],
                onChanged: (v) =>
                    setSheet(() => threshold = v ?? 80),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.tr('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(ctx.tr('common.save')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final value =
        double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    if (scope == 'department' && deptId == null) return;
    final okMsg = context.tr('gov.saved');
    final errMsg = context.tr('gov.error');
    try {
      await getIt<WorkspaceRemoteDataSource>().createBudget({
        if (scope == 'department') 'department': deptId,
        if (scope == 'category') 'category': category,
        'amount': value,
        'alert_threshold': threshold,
      });
      _toast(okMsg);
      unawaited(_load());
    } catch (_) {
      _toast(errMsg, error: true);
    }
  }

  Future<void> _deleteBudget(int id) async {
    final okMsg = context.tr('gov.deleted');
    final errMsg = context.tr('gov.error');
    try {
      await getIt<WorkspaceRemoteDataSource>().deleteBudget(id);
      _toast(okMsg);
      unawaited(_load());
    } catch (_) {
      _toast(errMsg, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final depts = _departments;
    final budgets = _budgets;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('gov.title'))),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'budget',
            onPressed: _addBudget,
            child: const Icon(LucideIcons.circleGauge),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'dept',
            onPressed: _addDepartment,
            child: const Icon(LucideIcons.plus),
          ),
        ],
      ),
      body: _failed
          ? EmptyState(
              icon: LucideIcons.cloudOff,
              title: context.tr('common.loadError'),
              subtitle: context.tr('common.retry'),
              action: FilledButton.tonalIcon(
                onPressed: _load,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: Text(context.tr('common.retry')),
              ),
            )
          : depts == null || budgets == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Seuil d'approbation (étude §B) : au-delà,
                  // toute déclaration passe en attente de
                  // validation owner/manager — même pour un
                  // propriétaire (traçabilité renforcée).
                  _ThresholdTile(threshold: _threshold),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    icon: LucideIcons.folders,
                    title: context.tr('gov.depts'),
                  ),
                  if (depts.isEmpty)
                    _Hint(text: context.tr('gov.deptsEmpty'))
                  else
                    for (final d in depts)
                      _Tile(
                        title: '${d['name']}',
                        subtitle: context.tr('gov.dept'),
                        onDelete: () =>
                            _deleteDepartment(d['id'] as int),
                      ),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    icon: LucideIcons.circleGauge,
                    title: context.tr('gov.budgets'),
                  ),
                  if (budgets.isEmpty)
                    _Hint(text: context.tr('gov.budgetsEmpty'))
                  else
                    for (final b in budgets)
                      _BudgetTile(
                        budget: b,
                        usage: _usage[b['id']],
                        onDelete: () =>
                            _deleteBudget(b['id'] as int),
                      ),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    icon: LucideIcons.truck,
                    title: context.tr('gov.suppliers'),
                  ),
                  const _Suppliers(),
                  const SizedBox(height: 24),
                  // Intégrations externes (étude Phase 4) : URL
                  // notifiée par POST JSON sur paiements/échéances.
                  _SectionTitle(
                    icon: LucideIcons.webhook,
                    title: context.tr('gov.webhooks'),
                  ),
                  const _Webhooks(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.subtitle,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: IconButton(
          icon: Icon(LucideIcons.trash2,
              size: 18, color: scheme.error),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.budget,
    required this.usage,
    required this.onDelete,
  });

  final Map<String, dynamic> budget;
  final Map<String, dynamic>? usage;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = usage?['status'] as String? ?? 'ok';
    final percent = (usage?['usage_percent'] as num?)?.toDouble();
    final color = switch (status) {
      'over' => scheme.error,
      'warning' => Colors.orange,
      _ => scheme.primary,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Text(
                  '${usage?['label'] ?? budget['category'] ?? '—'}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                AppFormatters.money(
                  double.tryParse('${budget['amount']}') ?? 0,
                  '',
                ),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.trash2,
                    size: 18, color: scheme.error),
                onPressed: onDelete,
              ),
            ],
          ),
          if (percent != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0, 1),
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('gov.usage', {
                'percent': percent.toStringAsFixed(0),
              }),
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Seuil d'approbation (étude §B) : montant au-delà duquel
/// toute déclaration de paiement passe en attente de
/// validation — affiche la valeur actuelle et permet de
/// l'ajuster (PATCH /workspace/setup/).
class _ThresholdTile extends StatefulWidget {
  const _ThresholdTile({required this.threshold});

  final Map<String, dynamic>? threshold;

  @override
  State<_ThresholdTile> createState() => _ThresholdTileState();
}

class _ThresholdTileState extends State<_ThresholdTile> {
  Future<void> _edit() async {
    final ctrl = TextEditingController(
      text: '${widget.threshold?['approval_threshold'] ?? ''}'
          .replaceAll('null', ''),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('gov.thrTitle')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: InputDecoration(
            labelText: ctx.tr('gov.thrHint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.tr('common.save')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final value = double.tryParse(
      ctrl.text.trim().replaceAll(',', '.'),
    );
    if (value == null || value < 0) return;
    final okMsg = context.tr('gov.saved');
    final errMsg = context.tr('gov.error');
    try {
      await getIt<WorkspaceRemoteDataSource>().updateCompany({
        'approval_threshold': value.toStringAsFixed(2),
      });
      _toast(okMsg);
      _refresh();
    } catch (_) {
      _toast(errMsg, error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    toastification.show(
      context: context,
      type: error
          ? ToastificationType.error
          : ToastificationType.success,
      title: Text(msg),
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  void _refresh() {
    final state = context.findAncestorStateOfType<
        _GovernancePageState>();
    unawaited(state?._load() ?? Future<void>.value());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final raw = widget.threshold?['approval_threshold'];
    final current = double.tryParse('$raw');
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(LucideIcons.shieldCheck,
            color: scheme.primary),
        title: Text(
          context.tr('gov.thrTitle'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          current != null
              ? context.tr('gov.thrCurrent', {
                  'amount': AppFormatters.money(
                    current,
                    '${widget.threshold?['default_currency'] ?? ''}',
                  ),
                })
              : context.tr('gov.thrNone'),
        ),
        trailing: IconButton(
          icon: const Icon(LucideIcons.penLine, size: 18),
          onPressed: _edit,
        ),
      ),
    );
  }
}

/// Fournisseurs/contrats (étude §E1) : liste + ajout +
/// suppression — contact, délai de règlement, préavis.
class _Suppliers extends StatefulWidget {
  const _Suppliers();

  @override
  State<_Suppliers> createState() => _SuppliersState();
}

class _SuppliersState extends State<_Suppliers> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  WorkspaceRemoteDataSource get _ds =>
      getIt<WorkspaceRemoteDataSource>();

  Future<void> _load() async {
    try {
      final list = await _ds.suppliers();
      if (mounted) setState(() => _items = list);
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final contact = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('gov.supAdd')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: ctx.tr('gov.name'),
              ),
            ),
            TextField(
              controller: contact,
              decoration: InputDecoration(
                labelText: ctx.tr('gov.supContact'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.tr('common.save')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final n = name.text.trim();
    if (n.isEmpty) return;
    final okMsg = context.tr('gov.saved');
    final errMsg = context.tr('gov.error');
    try {
      await _ds.addSupplier({
        'name': n,
        'contact': contact.text.trim(),
      });
      _toast(okMsg);
      unawaited(_load());
    } catch (_) {
      _toast(errMsg, error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    toastification.show(
      context: context,
      type: error
          ? ToastificationType.error
          : ToastificationType.success,
      title: Text(msg),
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        if (items.isEmpty)
          _Hint(text: context.tr('gov.supEmpty'))
        else
          for (final s in items)
            _Tile(
              title: '${s['name']}',
              subtitle: [
                if ('${s['contact']}'.isNotEmpty)
                  '${s['contact']}',
                '${s['payment_terms_days'] ?? 30} j',
              ].join(' · '),
              onDelete: () async {
                await _ds.deleteSupplier(s['id'] as int);
                unawaited(_load());
              },
            ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: Text(context.tr('gov.supAdd')),
          ),
        ),
      ],
    );
  }
}

/// Webhooks sortants (étude Phase 4) : URL notifiée par POST
/// JSON sur les événements choisis — base des connecteurs
/// comptables et intégrations externes.
class _Webhooks extends StatefulWidget {
  const _Webhooks();

  @override
  State<_Webhooks> createState() => _WebhooksState();
}

class _WebhooksState extends State<_Webhooks> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  WorkspaceRemoteDataSource get _ds =>
      getIt<WorkspaceRemoteDataSource>();

  Future<void> _load() async {
    try {
      final list = await _ds.webhooks();
      if (mounted) setState(() => _items = list);
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    }
  }

  Future<void> _add() async {
    final url = TextEditingController();
    final secret = TextEditingController();
    final events = <String>{'payment', 'subscription'};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => AlertDialog(
          title: Text(ctx.tr('gov.whAdd')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: url,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'URL (https://…)',
                ),
              ),
              TextField(
                controller: secret,
                decoration: InputDecoration(
                  labelText: ctx.tr('gov.whSecret'),
                ),
              ),
              const SizedBox(height: 8),
              for (final e in [
                'payment', 'subscription', 'overdue',
              ])
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(ctx.tr('wh.$e')),
                  value: events.contains(e),
                  onChanged: (v) => setSheet(() {
                    if (v == true) {
                      events.add(e);
                    } else {
                      events.remove(e);
                    }
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.tr('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(ctx.tr('common.save')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final u = url.text.trim();
    if (!u.startsWith('http')) return;
    final okMsg = context.tr('gov.saved');
    final errMsg = context.tr('gov.error');
    try {
      await _ds.addWebhook({
        'url': u,
        'secret': secret.text.trim(),
        'events': events.join(','),
      });
      _toast(okMsg);
      unawaited(_load());
    } catch (_) {
      _toast(errMsg, error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    toastification.show(
      context: context,
      type: error
          ? ToastificationType.error
          : ToastificationType.success,
      title: Text(msg),
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        if (items.isEmpty)
          _Hint(text: context.tr('gov.whEmpty'))
        else
          for (final w in items)
            _Tile(
              title: '${w['url']}',
              subtitle: [
                '${w['events']}',
                if (w['active'] == false)
                  context.tr('wh.inactive'),
              ].join(' · '),
              onDelete: () async {
                await _ds.deleteWebhook(w['id'] as int);
                unawaited(_load());
              },
            ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: Text(context.tr('gov.whAdd')),
          ),
        ),
      ],
    );
  }
}
