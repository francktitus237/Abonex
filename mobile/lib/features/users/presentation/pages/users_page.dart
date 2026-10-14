import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/animated_fade_in.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../auth/domain/entities/user.dart';

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
        SnackBar(content: Text('${user.email} est maintenant ${role.label}.')),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map<String, dynamic> && data['role'] is List
          ? (data['role'] as List).first.toString()
          : 'Impossible de modifier ce rôle.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs & rôles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Invitation : endpoint backend prévu au sprint auth+équipe.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invitation : bientôt disponible via l\'API.'),
            ),
          );
        },
        icon: const Icon(LucideIcons.userPlus, size: 20),
        label: const Text('Inviter'),
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
                  const Text('Impossible de charger les utilisateurs.'),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () => setState(() => _future = _load()),
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    label: const Text('Réessayer'),
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
                          'Les droits sont vérifiés côté serveur à chaque action.',
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
  const _UserTile({required this.user, required this.onRoleChanged});

  final User user;
  final ValueChanged<UserRole> onRoleChanged;

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
          else
            PopupMenuButton<UserRole>(
              tooltip: 'Modifier le rôle',
              initialValue: user.role,
              onSelected: onRoleChanged,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: UserRole.manager,
                  child: Text('Gestionnaire'),
                ),
                PopupMenuItem(
                  value: UserRole.assistant,
                  child: Text('Assistant'),
                ),
                PopupMenuItem(value: UserRole.viewer, child: Text('Lecteur')),
              ],
              child: _RoleBadge(role: user.role, editable: true),
            ),
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
            role.label,
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
