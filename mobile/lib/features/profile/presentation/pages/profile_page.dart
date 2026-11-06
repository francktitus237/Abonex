import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/countries.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/navigation/tab_reselect.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/storage/settings_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/animated_fade_in.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';
import '../../../workspace/data/datasources/workspace_remote_datasource.dart';

/// Onglet Profil : identité du compte + réglages P1 du CDC
/// (thème, langue, biométrie) + déconnexion.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// Scroll principal — re-tap sur « Profil » remonte en haut
  /// et recharge le profil utilisateur (/auth/me/).
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    getIt<TabReselect>().tick.addListener(_onTabReselect);
  }

  void _onTabReselect() {
    if (getIt<TabReselect>().lastIndex != 4 || !mounted) return;
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
    unawaited(context.read<AuthCubit>().refresh());
  }

  @override
  void dispose() {
    getIt<TabReselect>().tick.removeListener(_onTabReselect);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile.title'))),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          return switch (state) {
            Authenticated(:final user) =>
              _ProfileView(user: user, scroll: _scroll),
            // Pendant le bootstrap ou une déconnexion en cours.
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.user, required this.scroll});

  final User user;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20 + AppShell.barInset),
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
              _RingtoneTile(),
              const Divider(indent: 56),
              _BiometricTile(),
              const Divider(indent: 56),
              _PasswordTile(),
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
                // Employés : entreprise ET particulier — un
                // particulier suit aussi sa ménagère ou son
                // vigile (salaires = échéances payroll).
                ...[
                  const Divider(indent: 56),
                  ListTile(
                    leading: _TileIcon(icon: LucideIcons.userRoundCog),
                    title: Text(context.tr('profile.employees')),
                    subtitle: Text(context.tr('profile.employeesSub')),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    onTap: () => context.push(AppRoutes.employees),
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),

        // ---------- Application ----------
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 220),
          child: const _SectionTitle('Application'),
        ),
        const SizedBox(height: 10),
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 240),
          child: _Card(children: [_UpdateTile()]),
        ),

        const SizedBox(height: 20),

        // ---------- Données & compte (export RGPD, suppression) ----------
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 260),
          child: _Card(
            children: [
              ListTile(
                leading: const Icon(LucideIcons.fileDown, size: 20),
                title: Text(context.tr('profile.exportData')),
                subtitle: Text(context.tr('profile.exportDataSub')),
                onTap: () => _exportData(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  LucideIcons.trash2,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  context.tr('profile.deleteAccount'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: Text(context.tr('profile.deleteAccountSub')),
                onTap: () => _confirmDeleteAccount(context),
              ),
            ],
          ),
        ),

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

// ============ Données & compte ============

/// Télécharge le CSV RGPD/compta puis propose le partage
/// (Drive, mail, fichiers…) via la feuille système.
Future<void> _exportData(BuildContext context) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/abonex_export_'
        '${DateTime.now().millisecondsSinceEpoch}.csv';
    await getIt<WorkspaceRemoteDataSource>().exportCsv(path);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: 'Abonex export'),
    );
  } catch (_) {
    if (context.mounted) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.flat,
        title: Text(context.tr('profile.exportFail')),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }
}

/// Suppression définitive du compte : mot de passe requis,
/// puis logout local après confirmation serveur.
Future<void> _confirmDeleteAccount(BuildContext context) async {
  final pwdCtrl = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        LucideIcons.triangleAlert,
        color: Theme.of(ctx).colorScheme.error,
      ),
      title: Text(ctx.tr('profile.deleteAccount')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ctx.tr('profile.deleteWarn')),
          const SizedBox(height: 12),
          TextField(
            controller: pwdCtrl,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: ctx.tr('profile.password'),
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
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ctx.tr('profile.deleteAccount')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await getIt<WorkspaceRemoteDataSource>().deleteAccount(pwdCtrl.text);
    if (!context.mounted) return;
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flat,
      title: Text(context.tr('profile.deleted')),
      autoCloseDuration: const Duration(seconds: 3),
    );
    context.read<AuthCubit>().logout();
  } catch (_) {
    if (context.mounted) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.flat,
        title: Text(context.tr('profile.deleteFail')),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
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
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl != null
                ? null
                : Text(
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

  /// Bottom sheet d'édition : photo, prénom, nom, email, devise
  /// de base — PATCH /auth/me/ + /workspace/setup/ pour la devise.
  static void _showEditProfileSheet(BuildContext context, User user) {
    final firstName = TextEditingController(text: user.firstName);
    final lastName = TextEditingController(text: user.lastName);
    final email = TextEditingController(text: user.email);
    final canEditCurrency = user.role.canEditFinancials;
    var currency = user.workspace?.defaultCurrency ?? '';
    var avatarUrl = user.avatarUrl;
    var saving = false;
    var photoBusy = false;
    // Capturé avant les async gaps du sheet.
    final cubit = context.read<AuthCubit>();

    Future<void> pickPhoto(StateSetter setSheetState) async {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (files.isEmpty) return;
      final path = files.single.path;
      if (path == null) return;
      setSheetState(() => photoBusy = true);
      try {
        final shrunk = await _shrinkImage(path);
        final result = await cubit.uploadAvatar(shrunk);
        setSheetState(() {
          photoBusy = false;
          if (result case Ok(value: final u)) avatarUrl = u.avatarUrl;
        });
      } catch (_) {
        setSheetState(() => photoBusy = false);
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottom = MediaQuery.viewInsetsOf(context).bottom;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('profile.edit'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                // ---------- Photo de profil ----------
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.12),
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl!)
                          : null,
                      child: photoBusy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : avatarUrl == null
                          ? Icon(
                              LucideIcons.user,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          TextButton.icon(
                            onPressed: photoBusy
                                ? null
                                : () => pickPhoto(setSheetState),
                            icon: const Icon(LucideIcons.imagePlus, size: 18),
                            label: Text(context.tr('profile.photo.change')),
                          ),
                          if (avatarUrl != null)
                            TextButton.icon(
                              onPressed: photoBusy
                                  ? null
                                  : () async {
                                      setSheetState(() => photoBusy = true);
                                      await cubit.removeAvatar();
                                      setSheetState(() {
                                        photoBusy = false;
                                        avatarUrl = null;
                                      });
                                    },
                              icon: const Icon(LucideIcons.trash2, size: 18),
                              label: Text(
                                context.tr('profile.photo.remove'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
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
                const SizedBox(height: 14),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: context.tr('common.email'),
                    prefixIcon: Icon(LucideIcons.mail, size: 20),
                  ),
                ),
                // ---------- Devise de base du workspace ----------
                if (canEditCurrency) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: currency.isEmpty ? null : currency,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.tr('profile.currency'),
                      prefixIcon: Icon(LucideIcons.coins, size: 20),
                    ),
                    items: [
                      for (final c in _currencies)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) =>
                        setSheetState(() => currency = v ?? currency),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          setSheetState(() => saving = true);
                          final newEmail = email.text.trim();
                          var result = await cubit.updateProfile(
                            firstName: firstName.text.trim(),
                            lastName: lastName.text.trim(),
                            email: newEmail == user.email ? null : newEmail,
                          );
                          // Devise : endpoint workspace dédié —
                          // enchaîné seulement si le profil a réussi.
                          if (result is Ok &&
                              canEditCurrency &&
                              currency != (user.workspace?.defaultCurrency ?? '')) {
                            result = await cubit.updateWorkspaceCurrency(
                              currency,
                            );
                          }
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
                                      Err(failure: final f) =>
                                        f.localizedMessage,
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
                  label: Text(
                    context.tr(saving ? 'profile.saving' : 'profile.save'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Devises proposées — union des devises des pays supportés.
  static final _currencies =
      ({for (final c in AppCountries.all) c.currency}.toList()..sort());
}

/// Réduit l'image dans un carré de [max] px (PNG) — les photos de
/// téléphone dépassent facilement la limite serveur de 5 Mo.
Future<String> _shrinkImage(String path, {int max = 512}) async {
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: max,
      targetHeight: max,
    );
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (png == null) return path;
    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await out.writeAsBytes(png.buffer.asUint8List());
    return out.path;
  } catch (_) {
    // Fichier illisible → on envoie l'original, le serveur validera.
    return path;
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
      // Ancêtre Material obligatoire : sans lui, l'effet ripple et
      // la couleur de sélection des ListTile enfants sont invisibles
      // (avertissement framework dans les logs).
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
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
  State<_ReminderScheduleTile> createState() => _ReminderScheduleTileState();
}

class _ReminderScheduleTileState extends State<_ReminderScheduleTile> {
  static const _choices = [14, 7, 3, 2, 1, 0];
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
                        onChanged: (v) => setDialog(() => hour = v.round()),
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

/// Sonnerie des alarmes : sons intégrés ou fichier audio importé
/// par l'utilisateur. Le choix est relu par le planificateur à
/// chaque programmation — il s'applique aux prochaines alarmes.
class _RingtoneTile extends StatefulWidget {
  @override
  State<_RingtoneTile> createState() => _RingtoneTileState();
}

class _RingtoneTileState extends State<_RingtoneTile> {
  static const _builtin = ['default', 'classic', 'digital', 'chime'];
  SettingsStorage get _storage => getIt<SettingsStorage>();
  late String _selected = _storage.alarmSound;
  bool _busy = false;

  String _labelFor(BuildContext context, String value) => switch (value) {
    'classic' => context.tr('alarm.opt.classic'),
    'digital' => context.tr('alarm.opt.digital'),
    'chime' => context.tr('alarm.opt.chime'),
    'custom' => context.tr('alarm.opt.custom', {
      'name': _storage.alarmCustomName,
    }),
    _ => context.tr('alarm.opt.default'),
  };

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.audio);
      if (files.isEmpty) return;
      final picked = files.single;
      final path = picked.path;
      if (path == null) return;
      // Copie en zone privée : le chemin source (cache du picker)
      // peut être nettoyé par le système.
      final dir = await getApplicationSupportDirectory();
      final ext = path.contains('.') ? path.split('.').last : 'mp3';
      final dest = File('${dir.path}/alarm_custom.$ext');
      await File(path).copy(dest.path);
      var soundUri = dest.path;
      if (Platform.isAndroid) {
        // Android : le son est joué par le SYSTEMUI, qui ne lit PAS
        // le stockage privé de l'app — un file:// reste muet.
        // On l'insère donc dans le MediaStore → URI content://
        // lisible par le système (canal natif MainActivity).
        try {
          const channel = MethodChannel('abonex/media_store');
          soundUri = await channel.invokeMethod<String>(
                'importSound',
                {'path': dest.path, 'name': picked.name},
              ) ??
              soundUri;
          // Ancienne entrée MediaStore : supprimée pour ne pas
          // empiler les copies à chaque nouvel import.
          final old = _storage.alarmCustomPath;
          if (old != null && old.startsWith('content://')) {
            await channel.invokeMethod<void>('deleteSound', {'uri': old});
          }
        } catch (_) {
          // Échec natif → on garde le chemin fichier en repli
          // (certains appareils lisent quand même file://).
        }
      }
      await _storage.setCustomAlarmSound(soundUri, picked.name);
      if (!mounted) return;
      setState(() => _selected = 'custom');
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.flat,
        title: Text(context.tr('alarm.imported', {'name': picked.name})),
        autoCloseDuration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    final service = getIt<NotificationService>();
    var notifEnabled = await service.notificationsEnabled();
    var exactAllowed = await service.exactAlarmsAllowed();
    // Sélection locale au dialogue : un tap sur un radio ne ferme
    // plus le popup — l'utilisateur peut écouter CHAQUE sonnerie
    // avant de valider. Déclaré hors du builder pour survivre aux
    // reconstructions de StatefulBuilder.
    var choice = _selected;
    if (!mounted) return;
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(ctx.tr('alarm.choose')),
          // Le contenu est plus haut que l'écran sur petits
          // appareils (options + batterie + avertissement) —
          // scrollable évite l'overflow RenderFlex.
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notifications bloquées → rien ne sonnera : on le
              // dit au lieu de laisser l'utilisateur chercher.
              if (!notifEnabled)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      ctx,
                    ).colorScheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.bellOff,
                        size: 18,
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ctx.tr('alarm.disabled'),
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              RadioGroup<String>(
                groupValue: choice,
                onChanged: (val) => setD(() => choice = val ?? choice),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final v in _builtin)
                      RadioListTile<String>(
                        value: v,
                        title: Text(_labelFor(ctx, v)),
                      ),
                    if (_storage.alarmCustomName.isNotEmpty)
                      RadioListTile<String>(
                        value: 'custom',
                        title: Text(_labelFor(ctx, 'custom')),
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(LucideIcons.fileAudio, size: 20),
                title: Text(ctx.tr('alarm.import')),
                onTap: () => Navigator.of(ctx).pop('__import__'),
              ),
              const Divider(height: 8),
              // OEM agressifs (Infinix/XOS, Xiaomi/MIUI…) : sans
              // exemption batterie les alarmes sont tuées en
              // arrière-plan sur certains téléphones.
              if (Platform.isAndroid) ...[
                // Permission « Alarmes et rappels » refusée : les
                // sonneries passent en mode approximatif (retardées
                // voire absorbées par l'économiseur) — on le signale
                // et on propose l'activation directement ici.
                if (!exactAllowed)
                  ListTile(
                    leading: Icon(
                      LucideIcons.alarmClock,
                      size: 20,
                      color: Theme.of(ctx).colorScheme.error,
                    ),
                    title: Text(
                      ctx.tr('alarm.exactWarn'),
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                    ),
                    subtitle: Text(ctx.tr('alarm.exactEnable')),
                    dense: true,
                    onTap: () async {
                      final ok = await service.requestExactAlarms();
                      setD(() => exactAllowed = ok);
                    },
                  ),
                ListTile(
                  leading: const Icon(LucideIcons.batteryCharging, size: 20),
                  title: Text(ctx.tr('alarm.battery')),
                  subtitle: Text(ctx.tr('alarm.batterySub')),
                  dense: true,
                  onTap: () =>
                      Permission.ignoreBatteryOptimizations.request(),
                ),
                // Alarme de test réelle : vérifie tout le circuit
                // (canal + sonnerie + programmation exacte) sans
                // créer de faux rendez-vous.
                ListTile(
                  leading: const Icon(LucideIcons.bellRing, size: 20),
                  title: Text(ctx.tr('alarm.testRing')),
                  subtitle: Text(ctx.tr('alarm.testScheduled')),
                  dense: true,
                  onTap: () async {
                    await service.scheduleTestAlarm();
                    if (!ctx.mounted || !mounted) return;
                    Navigator.of(ctx).pop();
                    toastification.show(
                      context: context,
                      type: ToastificationType.info,
                      style: ToastificationStyle.flat,
                      title: Text(context.tr('alarm.testScheduled')),
                      autoCloseDuration: const Duration(seconds: 4),
                    );
                  },
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  ctx.tr('alarm.volumeHint'),
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (!notifEnabled)
              TextButton(
                onPressed: () async {
                  var ok = await service.requestPermissions();
                  ok = ok && await service.notificationsEnabled();
                  // Permission définitivement refusée → on envoie
                  // l'utilisateur dans les réglages système.
                  if (!ok) await openAppSettings();
                  setD(() => notifEnabled = ok);
                },
                child: Text(ctx.tr('alarm.enable')),
              ),
            TextButton(
              // Aperçu : joue la sonnerie SURVOLÉE (pas encore
              // sauvegardée). False = notifications bloquées → on
              // bascule sur l'avertissement au lieu d'un silence
              // inexpliqué.
              onPressed: () async {
                final ok = await service.previewAlarmSound(
                  soundKey: choice,
                );
                if (!ok) {
                  setD(() => notifEnabled = false);
                  if (mounted) {
                    toastification.show(
                      context: context,
                      type: ToastificationType.warning,
                      style: ToastificationStyle.flat,
                      title: Text(context.tr('alarm.blocked')),
                      autoCloseDuration: const Duration(seconds: 4),
                    );
                  }
                }
              },
              child: Text(ctx.tr('alarm.test')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.tr('common.cancel')),
            ),
            // La confirmation est un bouton explicite : choisir un
            // radio ne ferme plus le dialogue (écoute libre avant).
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(choice),
              child: Text(ctx.tr('common.confirm')),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    if (chosen == '__import__') {
      await _import();
      return;
    }
    await _storage.setAlarmSound(chosen);
    setState(() => _selected = chosen);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _TileIcon(icon: LucideIcons.music),
      title: Text(context.tr('alarm.title')),
      subtitle: Text(_labelFor(context, _selected)),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.chevronRight, size: 18),
      onTap: _busy ? null : _choose,
    );
  }
}

/// Changement de mot de passe : le serveur exige l'ancien
/// (anti-vol de session si le téléphone est déverrouillé).
class _PasswordTile extends StatelessWidget {
  Future<void> _change(BuildContext context) async {
    final cubit = context.read<AuthCubit>();
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    var saving = false;
    String? error;

    final done = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(ctx.tr('profile.password')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: ctx.tr('profile.password.current'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: next,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: ctx.tr('profile.password.new'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: ctx.tr('profile.password.confirm'),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontSize: 12,
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
              onPressed: saving
                  ? null
                  : () async {
                      if (next.text != confirm.text) {
                        setD(
                          () => error = ctx.tr('profile.password.mismatch'),
                        );
                        return;
                      }
                      setD(() {
                        saving = true;
                        error = null;
                      });
                      final result = await cubit.changePassword(
                        current.text,
                        next.text,
                      );
                      if (!ctx.mounted) return;
                      switch (result) {
                        case Ok():
                          Navigator.of(ctx).pop(true);
                        case Err(failure: final f):
                          setD(() {
                            saving = false;
                            error = f.localizedMessage;
                          });
                      }
                    },
              child: Text(ctx.tr('profile.save')),
            ),
          ],
        ),
      ),
    );
    if (done == true && context.mounted) {
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.flat,
        title: Text(context.tr('profile.password.changed')),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _TileIcon(icon: LucideIcons.keyRound),
      title: Text(context.tr('profile.password')),
      subtitle: Text(context.tr('profile.passwordSub')),
      trailing: const Icon(LucideIcons.chevronRight, size: 18),
      onTap: () => _change(context),
    );
  }
}

/// Mise à jour de l'application : compare la version installée
/// (package_info) avec la dernière publiée par le serveur
/// (/meta/app-version/) et propose le téléchargement.
class _UpdateTile extends StatefulWidget {
  @override
  State<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<_UpdateTile> {
  bool _checking = false;
  String _current = '…';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then(
      (info) => mounted ? setState(() => _current = info.version) : null,
    );
  }

  /// "1.10.0" > "1.9.9" — comparaison sémantique par segments.
  static bool _isNewer(String latest, String current) {
    List<int> parts(String v) =>
        v.split(RegExp(r'[.\-+]')).map((s) => int.tryParse(s) ?? 0).toList();
    final a = parts(latest), b = parts(current);
    for (var i = 0; i < a.length || i < b.length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final remote = await getIt<WorkspaceRemoteDataSource>().appVersion();
      final latest = remote['latest_version'] as String? ?? _current;
      final url = remote['update_url'] as String? ?? '';
      if (!mounted) return;
      if (_isNewer(latest, _current)) {
        _offerUpdate(latest, url);
      } else {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.flat,
          title: Text(context.tr('update.upToDate')),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (_) {
      if (!mounted) return;
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.flat,
        title: Text(context.tr('update.checkFail')),
        autoCloseDuration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _offerUpdate(String latest, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          LucideIcons.arrowDownToLine,
          color: Theme.of(ctx).colorScheme.primary,
        ),
        title: Text(ctx.tr('update.available')),
        content: Text(
          ctx.tr('update.body', {'latest': latest, 'current': _current}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.tr('common.later')),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (url.isNotEmpty) {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(LucideIcons.download, size: 18),
            label: Text(ctx.tr('update.action')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _TileIcon(icon: LucideIcons.arrowDownToLine),
      title: Text(context.tr('update.title')),
      subtitle: Text(context.tr('update.installed', {'v': _current})),
      trailing: _checking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.chevronRight, size: 18),
      onTap: _check,
    );
  }
}
