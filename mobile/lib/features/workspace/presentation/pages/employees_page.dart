import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/data/countries.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_converter.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_fade_in.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../subscriptions/presentation/cubit/subscriptions_cubit.dart';
import '../../data/datasources/workspace_remote_datasource.dart';
import '../../domain/entities/employee.dart';

/// Gestion des employés — réservée aux espaces entreprise.
/// Chaque employé actif génère côté serveur un abonnement
/// 'payroll' mensuel (dashboard, calendrier, rappels, CSV).
class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  List<Employee>? _items;
  String? _error;
  // Masse salariale convertie dans la devise de base du
  // workspace (repli multi-devises si taux indisponibles).
  String? _payrollLabel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Paie groupée du mois (étude §D/Phase 3) : confirmation →
  /// POST employees/pay-all/ → récap + resync échéances.
  Future<void> _payAll() async {
    final period = DateTime.now().toIso8601String().substring(0, 7);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('emp.payAll')),
        content: Text(
          ctx.tr('emp.payAllConfirm', {'period': period}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.tr('common.confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final okMsg = context.tr('emp.payAllDone');
    final errMsg = context.tr('emp.error');
    try {
      final res = await getIt<WorkspaceRemoteDataSource>()
          .payAll(period);
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: Text(
            '$okMsg — ${(res['paid'] as List?)?.length ?? 0}',
          ),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      unawaited(
        getIt<SubscriptionsCubit>().refresh(quiet: true),
      );
    } catch (_) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text(errMsg),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final raw = await getIt<WorkspaceRemoteDataSource>().employees();
      if (!mounted) return;
      setState(() => _items = raw.map(Employee.fromJson).toList());
      unawaited(_refreshPayrollLabel());
    } catch (_) {
      if (mounted) setState(() => _error = context.tr('common.loadError'));
    }
  }

  /// Masse salariale des employés actifs : convertie dans la
  /// devise de base (un employé en EUR + un en XAF → un seul
  /// total en XAF). Repli sur la liste par devise si l'endpoint
  /// de taux est injoignable.
  Future<void> _refreshPayrollLabel() async {
    final active = (_items ?? const <Employee>[])
        .where((e) => e.active)
        .toList();
    if (active.isEmpty) {
      if (mounted) setState(() => _payrollLabel = null);
      return;
    }
    final ws = switch (context.read<AuthCubit>().state) {
      Authenticated(user: final u) => u.workspace,
      _ => null,
    };
    final base = ws?.defaultCurrency ?? 'XAF';
    String label;
    try {
      final total = await getIt<CurrencyConverter>().convertAll(
        active.map((e) => (amount: e.salary, currency: e.currency)),
        base,
      );
      label = AppFormatters.money(total, base);
    } catch (_) {
      label = active
          .fold<Map<String, double>>({}, (m, e) {
            m[e.currency] = (m[e.currency] ?? 0) + e.salary;
            return m;
          })
          .entries
          .map((e) => AppFormatters.money(e.value, e.key))
          .join(' · ');
    }
    if (mounted) setState(() => _payrollLabel = label);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('emp.title')),
        actions: [
          // Paie groupée du mois (étude §D/Phase 3) : marque
          // payées toutes les échéances payroll actives et
          // agrège primes/avances/retenues du mois.
          IconButton(
            tooltip: context.tr('emp.payAll'),
            onPressed: _payAll,
            icon: const Icon(LucideIcons.banknote, size: 20),
          ),
          IconButton(
            tooltip: context.tr('common.refresh'),
            onPressed: _load,
            icon: const Icon(LucideIcons.refreshCw, size: 20),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context),
        icon: const Icon(LucideIcons.plus, size: 20),
        label: Text(context.tr('emp.add')),
      ),
      body: Column(
        children: [
          // ---------- Masse salariale ----------
          if (_payrollLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.banknote,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('emp.payroll', {
                          'amount': _payrollLabel!,
                        }),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: switch ((_items, _error)) {
              (null, null) => const Center(
                child: CircularProgressIndicator(),
              ),
              (_, final String e) => EmptyState(
                icon: LucideIcons.cloudOff,
                title: e,
                action: FilledButton.tonalIcon(
                  onPressed: _load,
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: Text(context.tr('common.retry')),
                ),
              ),
              (final List<Employee> list, _) when list.isEmpty =>
                EmptyState(
                  icon: LucideIcons.users,
                  title: context.tr('emp.empty'),
                  subtitle: context.tr('emp.emptySub'),
                  action: FilledButton.icon(
                    onPressed: () => _showForm(context),
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: Text(context.tr('emp.add')),
                  ),
                ),
              (final List<Employee> list, _) => RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => AnimatedFadeIn(
                    delay: Duration(milliseconds: 40 * i.clamp(0, 8)),
                    child: _EmployeeTile(
                      employee: list[i],
                      onTap: () => _showForm(context, existing: list[i]),
                    ),
                  ),
                ),
              ),
            },
          ),
        ],
      ),
    );
  }

  void _toast(String message, {bool error = false}) {
    toastification.show(
      context: context,
      type: error ? ToastificationType.error : ToastificationType.success,
      style: ToastificationStyle.flat,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  Future<void> _showForm(
    BuildContext context, {
    Employee? existing,
  }) async {
    final saved = await showModalBottomSheet<Employee>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EmployeeForm(existing: existing),
    );
    if (saved != null && context.mounted) {
      _toast(context.tr('emp.saved'));
      await _load();
    }
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.employee, required this.onTap});

  final Employee employee;
  final VoidCallback onTap;

  /// Ajoute prime/avance/retenue/HS pour le mois courant —
  /// agrégé à la paie groupée et au bulletin (étude §D).
  Future<void> _addItem(BuildContext context) async {
    final period =
        DateTime.now().toIso8601String().substring(0, 7);
    final label = TextEditingController();
    final amount = TextEditingController();
    var kind = 'bonus';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => AlertDialog(
          title: Text(ctx.tr('emp.addItem')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: kind,
                items: [
                  for (final k in [
                    'bonus', 'advance', 'deduction', 'overtime',
                    'contribution', 'tax',
                  ])
                    DropdownMenuItem(
                      value: k,
                      child: Text(ctx.tr('item.$k')),
                    ),
                ],
                onChanged: (v) =>
                    setSheet(() => kind = v ?? 'bonus'),
                decoration: InputDecoration(
                  labelText: ctx.tr('item.kind'),
                ),
              ),
              TextField(
                controller: label,
                decoration: InputDecoration(
                  labelText: ctx.tr('item.label'),
                ),
              ),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: ctx.tr('item.amount'),
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
      ),
    );
    if (ok != true || !context.mounted) return;
    final value = double.tryParse(
      amount.text.trim().replaceAll(',', '.'),
    );
    if (value == null || label.text.trim().isEmpty) return;
    final okMsg = context.tr('emp.itemAdded');
    final errMsg = context.tr('emp.error');
    try {
      await getIt<WorkspaceRemoteDataSource>().addPayrollItem({
        'employee': employee.id,
        'kind': kind,
        'label': label.text.trim(),
        'amount': value.toStringAsFixed(2),
        'period': period,
      });
      if (context.mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: Text(okMsg),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    } catch (_) {
      if (context.mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text(errMsg),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  /// Bulletin PDF du mois → téléchargé puis partagé (étude §D).
  Future<void> _payslip(BuildContext context) async {
    final period =
        DateTime.now().toIso8601String().substring(0, 7);
    final errMsg = context.tr('emp.payslipErr');
    try {
      final bytes = await getIt<WorkspaceRemoteDataSource>()
          .payslipBytes(employee.id, period);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/bulletin_${employee.name}_$period.pdf',
      );
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } catch (_) {
      if (context.mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text(errMsg),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: (employee.active
                        ? scheme.primary
                        : scheme.outline)
                    .withValues(alpha: 0.15),
                child: Text(
                  employee.name.isEmpty
                      ? '?'
                      : employee.name[0].toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: employee.active
                        ? scheme.primary
                        : scheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        if (employee.position.isNotEmpty)
                          employee.position,
                        'J${employee.payDay}',
                        if (!employee.active) '· inactif',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                AppFormatters.money(employee.salary, employee.currency),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              // Élément de paie : prime/avance/retenue/HS.
              IconButton(
                tooltip: context.tr('emp.addItem'),
                visualDensity: VisualDensity.compact,
                icon: Icon(LucideIcons.circlePlus,
                    size: 18, color: scheme.primary),
                onPressed: () => _addItem(context),
              ),
              // Bulletin de paie PDF du mois (étude §D).
              IconButton(
                tooltip: context.tr('emp.payslip'),
                visualDensity: VisualDensity.compact,
                icon: Icon(LucideIcons.fileText,
                    size: 18, color: scheme.primary),
                onPressed: () => _payslip(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formulaire d'ajout/édition d'employé — la création met
/// aussi à jour l'abonnement payroll côté serveur.
class _EmployeeForm extends StatefulWidget {
  const _EmployeeForm({this.existing});

  final Employee? existing;

  @override
  State<_EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<_EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _position = TextEditingController(
    text: widget.existing?.position ?? '',
  );
  late final _salary = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.salary.toStringAsFixed(0),
  );
  late int _payDay = widget.existing?.payDay ?? 25;
  late bool _active = widget.existing?.active ?? true;
  late String _currency = widget.existing?.currency ?? 'XAF';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Nouvelle fiche : la devise du workspace pré-remplit —
    // jamais de XAF forcé sur un compte en EUR/USD.
    if (widget.existing == null) {
      final ws = switch (context.read<AuthCubit>().state) {
        Authenticated(user: final u) => u.workspace,
        _ => null,
      };
      if (ws?.defaultCurrency?.isNotEmpty ?? false) {
        _currency = ws!.defaultCurrency!;
      }
    }
  }

  /// Devises choisies : workspace + extras en tête, puis toutes
  /// les monnaies couvertes par les pays supportés.
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
    _position.dispose();
    _salary.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    final payload = {
      'name': _name.text.trim(),
      'position': _position.text.trim(),
      'salary': double.tryParse(
            _salary.text.replaceAll(' ', '').replaceAll(',', '.'),
          ) ??
          0,
      'currency': _currency,
      'pay_day': _payDay,
      'active': _active,
    };
    try {
      final ds = getIt<WorkspaceRemoteDataSource>();
      final json = widget.existing == null
          ? await ds.createEmployee(payload)
          : await ds.updateEmployee(widget.existing!.id, payload);
      // La paie est régénérée côté serveur → resync silencieux.
      unawaited(
        getIt<SubscriptionsCubit>().refresh(quiet: true),
      );
      if (mounted) Navigator.of(context).pop(Employee.fromJson(json));
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr(
                widget.existing == null ? 'emp.add' : 'emp.edit',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.tr('emp.name'),
                prefixIcon: const Icon(LucideIcons.user, size: 20),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _position,
              decoration: InputDecoration(
                labelText: context.tr('emp.position'),
                prefixIcon: const Icon(LucideIcons.briefcase, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _salary,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('emp.salary'),
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
                          onChanged: (v) =>
                              setState(() => _currency = v!),
                        ),
                      ),
                    ),
                    validator: (v) =>
                        double.tryParse(
                          (v ?? '').replaceAll(' ', '').replaceAll(',', '.'),
                        ) ==
                            null
                        ? 'Montant invalide'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _payDay,
                    decoration: InputDecoration(
                      labelText: context.tr('emp.payDay'),
                    ),
                    items: List.generate(
                      31,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}'),
                      ),
                    ),
                    onChanged: (v) => setState(() => _payDay = v ?? 25),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('emp.active')),
              subtitle: Text(context.tr('emp.activeSub')),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(LucideIcons.check, size: 18),
              label: Text(context.tr('profile.save')),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
