import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/animated_fade_in.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../workspace/data/datasources/workspace_remote_datasource.dart';

/// Gestion des utilisateurs et rôles — réservée au Propriétaire.
/// Le guard du router bloque déjà l'accès aux autres rôles ;
/// Django refusera aussi les appels API (double verrou, CDC).
///
/// Données : GET /users/ — le backend Django.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late Future<List<User>> _future;
  // Données brutes /users/ indexées par id — membership_id et
  // custom_permissions pour le dialogue de capacités.
  Map<String, Map<String, dynamic>> _raw = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<User>> _load() async {
    try {
      final res = await getIt<Dio>().get<dynamic>(ApiEndpoints.users);
      final raw = res.data;
      final items = raw is Map<String, dynamic>
          ? raw['results'] as List<dynamic>
          : raw as List<dynamic>;
      // membership_id + custom_permissions par user — bruts,
      // le dialogue « capacités » les consomme (étude §4).
      _raw = {
        for (final e in items.cast<Map<String, dynamic>>())
          '${e['id']}': e,
      };
      return items.map(_parseUser).toList();
    } on DioException {
      // Pas de mode démo : l'erreur remonte, la page l'affiche
      // avec un bouton Réessayer.
      rethrow;
    }
  }

  Future<void> _changeRole(User user, UserRole role) async {
    try {
      await getIt<Dio>().patch<void>(
        ApiEndpoints.user(user.id),
        data: {'role': role.name},
      );
      if (!mounted) return;
      setState(() => _future = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('users.roleChanged', {
              'email': user.email,
              'role': context.tr(role.labelKey),
            }),
          ),
        ),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map<String, dynamic> && data['role'] is List
          ? (data['role'] as List).first.toString()
          : context.tr('users.roleFail');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Capacités additionnelles du membre (rôles personnalisés,
  /// étude Phase 4) : employees/payments/budgets/audit
  /// accordées AU-DELÀ du rôle — PATCH `memberships/<id>/`.
  Future<void> _capabilities(User user) async {
    final raw = _raw[user.id];
    final membershipId = raw?['membership_id'];
    if (membershipId == null) return;
    final caps = {
      for (final c in '${raw?['custom_permissions'] ?? ''}'
          .split(','))
        if (c.isNotEmpty) c,
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => AlertDialog(
          title: Text(ctx.tr('users.caps')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final cap in [
                'employees', 'payments', 'budgets', 'audit',
              ])
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(ctx.tr('users.cap.$cap')),
                  value: caps.contains(cap),
                  onChanged: (v) => setSheet(() {
                    if (v == true) {
                      caps.add(cap);
                    } else {
                      caps.remove(cap);
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
    if (saved != true || !mounted) return;
    try {
      await getIt<Dio>().patch<void>(
        'memberships/$membershipId/permissions/',
        data: {'custom_permissions': caps.join(',')},
      );
      if (!mounted) return;
      setState(() => _future = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('users.capSaved'))),
      );
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('users.capFail'))),
      );
    }
  }

  User _parseUser(dynamic e) {
    final json = e as Map<String, dynamic>;
    return User(
      id: json['id'].toString(),
      email: json['email'] as String,
      role: UserRole.parse(json['role'] as String? ?? ''),
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
    );
  }

  /// Envoie une invitation email avec le rôle choisi — le destinataire
  /// confirme via le lien et rejoint le workspace avec ce rôle.
  Future<void> _invite() async {
    final emailController = TextEditingController();
    var role = 'viewer';
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => AlertDialog(
          title: Text(ctx.tr('users.inviteTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: ctx.tr('common.email'),
                  hintText: ctx.tr('auth.emailHint'),
                  prefixIcon: const Icon(LucideIcons.mail, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: role,
                isExpanded: true,
                decoration: InputDecoration(labelText: ctx.tr('users.role')),
                items: [
                  DropdownMenuItem(
                    value: 'manager',
                    child: Text(ctx.tr('users.roleManager')),
                  ),
                  DropdownMenuItem(
                    value: 'assistant',
                    child: Text(ctx.tr('users.roleAssistant')),
                  ),
                  DropdownMenuItem(
                    value: 'viewer',
                    child: Text(ctx.tr('users.roleViewer')),
                  ),
                ],
                onChanged: (v) => setSheetState(() => role = v!),
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
              child: Text(ctx.tr('common.send')),
            ),
          ],
        ),
      ),
    );
    final email = emailController.text.trim();
    emailController.dispose();
    if (sent != true || !email.contains('@') || !mounted) return;
    try {
      await getIt<WorkspaceRemoteDataSource>().invite(email: email, role: role);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('users.inviteSent', {'email': email})),
        ),
      );
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('users.inviteFail'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile.users'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        icon: const Icon(LucideIcons.userPlus, size: 20),
        label: Text(context.tr('users.invite')),
      ),
      body: FutureBuilder<List<User>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.cloudOff, size: 40),
                  const SizedBox(height: 12),
                  Text(context.tr('users.loadFail')),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () => setState(() => _future = _load()),
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    label: Text(context.tr('common.retry')),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: SkeletonListView(itemCount: 5),
            );
          }
          final users = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(AppTheme.radius - 4),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.info,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('users.info'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...users.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AnimatedFadeIn(
                      delay: Duration(milliseconds: 50 * e.key),
                      child: _UserTile(
                        user: e.value,
                        onRoleChanged: (role) => _changeRole(e.value, role),
                        onCapabilities: _capabilities,
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
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onRoleChanged,
    required this.onCapabilities,
  });

  final User user;
  final ValueChanged<UserRole> onRoleChanged;
  final ValueChanged<User> onCapabilities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final initials = [
      user.firstName,
      user.lastName,
    ].where((p) => p != null && p.isNotEmpty);
    final label = initials.isEmpty
        ? user.email[0].toUpperCase()
        : initials.map((p) => p![0].toUpperCase()).join();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isEmpty ? user.email : user.fullName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (user.role == UserRole.owner)
            _RoleBadge(role: user.role)
          else ...[
            // Capacités additionnelles (rôles personnalisés).
            IconButton(
              tooltip: context.tr('users.caps'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(LucideIcons.keyRound, size: 18),
              onPressed: () => onCapabilities(user),
            ),
            PopupMenuButton<UserRole>(
              tooltip: context.tr('users.changeRole'),
              initialValue: user.role,
              onSelected: onRoleChanged,
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: UserRole.manager,
                  child: Text(ctx.tr('role.manager')),
                ),
                PopupMenuItem(
                  value: UserRole.assistant,
                  child: Text(ctx.tr('role.assistant')),
                ),
                PopupMenuItem(
                  value: UserRole.viewer,
                  child: Text(ctx.tr('role.viewer')),
                ),
              ],
              child: _RoleBadge(role: user.role, editable: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, this.editable = false});

  final UserRole role;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr(role.labelKey),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (editable) ...[
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 13, color: scheme.primary),
          ],
        ],
      ),
    );
  }
}
