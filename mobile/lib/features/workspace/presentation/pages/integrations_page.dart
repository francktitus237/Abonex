import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/di/injection.dart';
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
  bool _loadingConnectors = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadConnectors();
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

  // ---------- Import CSV ----------

  /// Colonnes attendues (1re ligne d'en-tête) :
  /// name, provider, category, amount, currency, cycle, next_due_date
  Future<void> _importCsv() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (picked.isEmpty) return;
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
          'currency': map['currency'] ?? 'XAF',
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
    } on Exception {
      if (mounted) _toast('Import impossible. Réessayez.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

          // --- Connecteurs ---
          _SectionCard(
            icon: LucideIcons.plugZap,
            title: 'Connecter vos comptes',
            subtitle:
                'Abonex récupère automatiquement vos services '
                '(serveurs, cloud, domaines) depuis le fournisseur.',
            child: _loadingConnectors
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      for (final c in _connectors)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                scheme.primary.withValues(alpha: 0.12),
                            child: Icon(LucideIcons.server,
                                size: 18, color: scheme.primary),
                          ),
                          title: Text(c['label'] as String),
                          subtitle: Text(
                            c['description'] as String? ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: _busy ? null : () => _connect(c),
                            child: const Text('Connecter'),
                          ),
                        ),
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
