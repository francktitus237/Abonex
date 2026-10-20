import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/storage/settings_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/animated_fade_in.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';

/// Onglet Profil : identité du compte + réglages P1 du CDC
/// (thème, langue, biométrie) + déconnexion.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile.title'))),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          return switch (state) {
            Authenticated(:final user) => _ProfileView(user: user),
            // Pendant le bootstrap ou une déconnexion en cours.
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ---------- Carte identité ----------
        AnimatedFadeIn(child: _IdentityCard(user: user)),
        const SizedBox(height: 28),

        // ---------- Préférences ----------
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 80),
          child: _SectionTitle(context.tr('profile.preferences')),
        ),
        const SizedBox(height: 10),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 120),
          child: _Card(
            children: [
              _ThemeModeTile(),
              const Divider(indent: 56),
              _LanguageTile(),
              const Divider(indent: 56),
              _SoundAlertsTile(),
              const Divider(indent: 56),
              _ReminderScheduleTile(),
              const Divider(indent: 56),
              _BiometricTile(),
            ],
          ),
        ),

        // ---------- Administration (visible selon le rôle) ----------
        // Le CDC : Flutter MASQUE l'interface, Django refuse côté serveur.
        if (user.role.canManageUsers) ...[
          const SizedBox(height: 28),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 160),
            child: _SectionTitle(context.tr('profile.admin')),
          ),
          const SizedBox(height: 10),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 200),
            child: _Card(
              children: [
                ListTile(
                  leading: _TileIcon(icon: LucideIcons.users),
                  title: Text(context.tr('profile.users')),
                  subtitle: Text(context.tr('profile.usersSub')),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => context.push(AppRoutes.users),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: _TileIcon(icon: LucideIcons.plugZap),
                  title: Text(context.tr('profile.integrations')),
                  subtitle: Text(context.tr('profile.integrationsSub')),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => context.push(AppRoutes.integrations),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),

        // ---------- Session ----------
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 240),
          child: OutlinedButton.icon(
            onPressed: () => context.read<AuthCubit>().logout(),
            icon: Icon(
              LucideIcons.logOut,
              size: 18,
              color: theme.colorScheme.error,
            ),
            label: Text(
              context.tr('profile.logout'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============ Sous-widgets ============

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: AppTheme.softShadow(theme.brightness),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              _initials(user),
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isEmpty ? user.email : user.fullName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _RoleChip(role: user.role),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('profile.edit'),
            onPressed: () => _showEditProfileSheet(context, user),
            icon: Icon(
              LucideIcons.pencil,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _initials(User user) {
    final parts = [
      user.firstName,
      user.lastName,
    ].where((p) => p != null && p.isNotEmpty);
    if (parts.isEmpty) return user.email[0].toUpperCase();
    return parts.map((p) => p![0].toUpperCase()).join();
  }

  /// Bottom sheet d'édition : prénom, nom, langue — PATCH /auth/me/.
  static void _showEditProfileSheet(BuildContext context, User user) {
    final firstName = TextEditingController(text: user.firstName);
    final lastName = TextEditingController(text: user.lastName);
    var saving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottom = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('profile.edit'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: firstName,
                  decoration: InputDecoration(
                    labelText: context.tr('profile.firstName'),
                    prefixIcon: Icon(LucideIcons.user, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: lastName,
                  decoration: InputDecoration(
                    labelText: context.tr('profile.lastName'),
                    prefixIcon: Icon(LucideIcons.userRound, size: 20),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          setSheetState(() => saving = true);
                          final result = await sheetContext
                              .read<AuthCubit>()
                              .updateProfile(
                                firstName: firstName.text.trim(),
                                lastName: lastName.text.trim(),
                              );
                          if (!context.mounted) return;
                          setSheetState(() => saving = false);
                          if (result is Ok) {
                            Navigator.of(context).pop();
                          }
                          toastification.show(
                            context: context,
                            type: result is Ok
                                ? ToastificationType.success
                                : ToastificationType.error,
                            style: ToastificationStyle.flat,
                            title: Text(
                              result is Ok
                                  ? context.tr('profile.updated')
                                  : switch (result) {
                                      Err(failure: final f) => f.message,
                                      _ => context.tr('profile.unexpected'),
                                    },
                            ),
                            autoCloseDuration: const Duration(seconds: 3),
                          );
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.check, size: 19),
                  label: Text(context.tr(saving ? 'profile.saving' : 'profile.save')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Badge de rôle — le libellé vient de l'extension métier sur UserRole.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.shieldCheck,
            size: 12,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            context.tr(role.labelKey),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Titre de section discret, en petites capitales.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Carte conteneur des lignes de réglages.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(children: children),
    );
  }
}

/// Pastille d'icône pour les lignes de réglages.
class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: scheme.primary),
    );
  }
}

// ---------- Réglages fonctionnels (SettingsCubit) ----------

class _ThemeModeTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (a, b) => a.themeMode != b.themeMode,
      builder: (context, settings) {
        return ListTile(
          leading: _TileIcon(icon: LucideIcons.sunMoon),
          title: Text(context.tr('settings.theme')),
          trailing: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(LucideIcons.sun, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(LucideIcons.moon, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(LucideIcons.monitorSmartphone, size: 16),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (modes) =>
                context.read<SettingsCubit>().setThemeMode(modes.first),
          ),
        );
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (a, b) => a.locale != b.locale,
      builder: (context, settings) {
        return ListTile(
          leading: _TileIcon(icon: LucideIcons.languages),
          title: Text(context.tr('settings.language')),
          trailing: SegmentedButton<String>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 'fr', label: Text('FR')),
              ButtonSegment(value: 'en', label: Text('EN')),
            ],
            selected: {settings.locale.languageCode},
            onSelectionChanged: (codes) {
              final code = codes.first;
              context.read<SettingsCubit>().setLocale(Locale(code));
              // Garde la langue du profil serveur alignée (best effort).
              context.read<AuthCubit>().updateProfile(language: code);
            },
          ),
        );
      },
    );
  }
}

class _BiometricTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (a, b) => a.biometricEnabled != b.biometricEnabled,
      builder: (context, settings) {
        return SwitchListTile(
          secondary: _TileIcon(icon: LucideIcons.fingerprint),
          title: Text(context.tr('settings.biometric')),
          subtitle: Text(context.tr('settings.biometricSub')),
          value: settings.biometricEnabled,
          onChanged: (enabled) async {
            final applied = await context
                .read<SettingsCubit>()
                .setBiometricEnabled(enabled);
            // Capteur absent ou auth annulée → le switch reste à false.
            if (!applied && context.mounted) {
              toastification.show(
                context: context,
                type: ToastificationType.warning,
                style: ToastificationStyle.flat,
                title: Text(context.tr('settings.biometricUnavailable')),
                autoCloseDuration: const Duration(seconds: 3),
              );
            }
          },
        );
      },
    );
  }
}

/// Rappels type alarme : notification plein écran + sonnerie
/// forte le jour J — interrupteur utilisateur.
class _SoundAlertsTile extends StatefulWidget {
  @override
  State<_SoundAlertsTile> createState() => _SoundAlertsTileState();
}

class _SoundAlertsTileState extends State<_SoundAlertsTile> {
  late bool _enabled = getIt<SettingsStorage>().soundAlerts;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: _TileIcon(icon: LucideIcons.bellRing),
      title: Text(context.tr('settings.sound')),
      subtitle: Text(context.tr('settings.soundSub')),
      value: _enabled,
      onChanged: (value) async {
        await getIt<SettingsStorage>().setSoundAlerts(value);
        if (mounted) setState(() => _enabled = value);
      },
    );
  }
}

/// Quand rappeler : jours d'anticipation (J-14 … J) + heure.
/// L'utilisateur personnalise sa cadence de rappel.
class _ReminderScheduleTile extends StatefulWidget {
  @override
  State<_ReminderScheduleTile> createState() =>
      _ReminderScheduleTileState();
}

class _ReminderScheduleTileState extends State<_ReminderScheduleTile> {
  static const _choices = [14, 7, 3, 1, 0];
  late List<int> _days = getIt<SettingsStorage>().reminderDays;
  late int _hour = getIt<SettingsStorage>().reminderHour;

  String _summary(BuildContext context) {
    final parts = _days.map((d) => d == 0 ? 'J' : 'J-$d').toList();
    return context.tr('reminder.summary', {
      'days': parts.join(', '),
      'hour': '$_hour',
    });
  }

  Future<void> _configure() async {
    var days = [..._days];
    var hour = _hour;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            title: Text(ctx.tr('reminder.title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.tr('reminder.remindMe'),
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in _choices)
                      FilterChip(
                        label: Text(d == 0 ? ctx.tr('reminder.dayJ') : 'J-$d'),
                        selected: days.contains(d),
                        showCheckmark: false,
                        onSelected: (on) => setDialog(() {
                          on ? days.add(d) : days.remove(d);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  ctx.tr('reminder.hour'),
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: hour.toDouble(),
                        min: 6,
                        max: 22,
                        divisions: 16,
                        label: '${hour}h',
                        onChanged: (v) =>
                            setDialog(() => hour = v.round()),
                      ),
                    ),
                    Text(
                      '${hour}h00',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (days.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      ctx.tr('reminder.atLeastOne'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
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
                onPressed: days.isEmpty
                    ? null
                    : () => Navigator.of(ctx).pop(true),
                child: Text(ctx.tr('profile.save')),
              ),
            ],
          );
        },
      ),
    );
    if (saved != true || !mounted) return;
    final storage = getIt<SettingsStorage>();
    await storage.setReminderDays(days);
    await storage.setReminderHour(hour);
    setState(() {
      _days = storage.reminderDays;
      _hour = storage.reminderHour;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _TileIcon(icon: LucideIcons.alarmClock),
      title: Text(context.tr('reminder.title')),
      subtitle: Text(_summary(context)),
      trailing: const Icon(LucideIcons.chevronRight, size: 18),
      onTap: _configure,
    );
  }
}