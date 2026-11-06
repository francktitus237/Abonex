import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/datasources/workspace_remote_datasource.dart';

/// Journal d'audit de l'espace — créations, paiements, suppressions,
/// changements de rôle. Réservé au propriétaire (étude §4.5).
class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  List<Map<String, dynamic>>? _items;
  bool _failed = false;

  static const _icons = {
    'create': LucideIcons.plus,
    'update': LucideIcons.penLine,
    'delete': LucideIcons.trash2,
    'pay': LucideIcons.banknote,
    'approve': LucideIcons.circleCheck,
    'reject': LucideIcons.circleX,
    'role_change': LucideIcons.shieldCheck,
    'member_remove': LucideIcons.userRoundMinus,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final items = await getIt<WorkspaceRemoteDataSource>().auditLog();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = _items;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('audit.title'))),
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
              icon: LucideIcons.scrollText,
              title: context.tr('audit.empty'),
              subtitle: context.tr('audit.emptySub'),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final e = items[i];
                  final action = '${e['action']}';
                  final at = DateTime.tryParse('${e['at']}');
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radius,
                      ),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: scheme.primaryContainer
                              .withValues(alpha: 0.5),
                          child: Icon(
                            _icons[action] ?? LucideIcons.history,
                            size: 16,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e['object_repr']}',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              Text(
                                '${context.tr('audit.$action')} · '
                                '${e['actor']}'
                                '${at != null ? ' · ${AppFormatters.dateLong(at)}' : ''}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
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
