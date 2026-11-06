import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../subscriptions/presentation/cubit/subscriptions_cubit.dart';
import '../../data/datasources/workspace_remote_datasource.dart';

/// « À valider » : déclarations de paiement des assistants en
/// attente — owner/manager approuve ou refuse avec motif.
class PendingPaymentsPage extends StatefulWidget {
  const PendingPaymentsPage({super.key});

  @override
  State<PendingPaymentsPage> createState() => _PendingPaymentsPageState();
}

class _PendingPaymentsPageState extends State<PendingPaymentsPage> {
  List<Map<String, dynamic>>? _items;
  bool _failed = false;
  final _busy = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final items =
          await getIt<WorkspaceRemoteDataSource>().pendingPayments();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    toastification.show(
      context: context,
      type: ToastificationType.info,
      title: Text(text),
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  Future<void> _verdict(Map<String, dynamic> p, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askReason();
      if (!mounted || reason == null) return;
    }
    final id = p['id'] as int;
    final okMsg = context.tr(
      approve ? 'pend.approved' : 'pend.rejected',
    );
    final errMsg = context.tr('pend.error');
    setState(() => _busy.add(id));
    try {
      await getIt<WorkspaceRemoteDataSource>().paymentVerdict(
        id,
        approve ? 'approved' : 'rejected',
        reason: reason,
      );
      _toast(okMsg);
      setState(() => _items!.removeWhere((e) => e['id'] == id));
      // Le statut de l'échéance change côté serveur.
      unawaited(
        getIt<SubscriptionsCubit>().refresh(quiet: true),
      );
    } catch (_) {
      _toast(errMsg);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<String?> _askReason() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('pend.reasonTitle')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: ctx.tr('pend.reasonHint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(ctx.tr('common.save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = _items;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('pend.title'))),
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
          : items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? EmptyState(
              icon: LucideIcons.circleCheck,
              title: context.tr('pend.empty'),
              subtitle: context.tr('pend.emptySub'),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final p = items[i];
                  final id = p['id'] as int;
                  final busy = _busy.contains(id);
                  final currency = p['currency'] as String? ?? 'XAF';
                  final amount = double.tryParse(
                    '${p['amount_paid'] ?? p['amount']}',
                  );
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radius,
                      ),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${p['name']}',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            Text(
                              amount != null
                                  ? AppFormatters.money(
                                      amount,
                                      currency,
                                    )
                                  : '—',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${p['declared_by']} · '
                          '${AppFormatters.dateLong(
                            DateTime.tryParse('${p['due_date']}') ??
                                DateTime.now(),
                          )}'
                          '${(p['method'] as String? ?? '').isNotEmpty ? ' · ${p['method']}' : ''}'
                          '${(p['reference'] as String? ?? '').isNotEmpty ? ' · ${p['reference']}' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => _verdict(p, false),
                                icon: const Icon(
                                  LucideIcons.x,
                                  size: 16,
                                ),
                                label: Text(
                                  context.tr('pend.reject'),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: scheme.error,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => _verdict(p, true),
                                icon: const Icon(
                                  LucideIcons.check,
                                  size: 16,
                                ),
                                label: Text(
                                  context.tr('pend.approve'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
