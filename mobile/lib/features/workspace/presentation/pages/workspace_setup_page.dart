import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/data/countries.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../data/datasources/workspace_remote_datasource.dart';

/// Configuration de premier démarrage — demandée par le client :
/// pays, langue, devise principale et invitation
/// de collaborateurs par email.
class WorkspaceSetupPage extends StatefulWidget {
  const WorkspaceSetupPage({super.key});

  @override
  State<WorkspaceSetupPage> createState() => _WorkspaceSetupPageState();
}

class _WorkspaceSetupPageState extends State<WorkspaceSetupPage> {
  Country? _country;
  String _currency = 'XAF';
  String _language = 'fr';
  String _role = 'owner';
  final _inviteController = TextEditingController();
  final List<({String email, String role})> _invites = [];

  bool _saving = false;

  static const _allCurrencies = [
    'XAF', 'XOF', 'EUR', 'USD', 'GBP', 'CHF', 'CAD', 'MAD', 'DZD',
    'TND', 'NGN', 'GHS', 'KES', 'ZAR', 'INR', 'CNY', 'AED', 'BRL',
  ];

  @override
  void initState() {
    super.initState();
    // Pré-remplissage intelligent : devise/langue selon la locale
    // du téléphone (ex. téléphone fr-FR → France, EUR).
    final deviceCountry =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    final detected = AppCountries.byCode(deviceCountry);
    if (detected != null) {
      _country = detected;
      _currency = detected.currency;
      _language = detected.languages.first;
    }
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_country == null) return;
    setState(() => _saving = true);
    try {
      final datasource = getIt<WorkspaceRemoteDataSource>();
      await datasource.setup(
        country: _country!.code,
        defaultCurrency: _currency,
        extraCurrencies: const [],
        language: _language,
      );
      for (final invite in _invites) {
        await datasource.invite(email: invite.email, role: invite.role);
      }
      if (!mounted) return;
      getIt<SettingsCubit>().setLocale(Locale(_language));
      await getIt<AuthCubit>().bootstrap();
      if (!mounted) return;
      context.go('/');
    } on Exception {
      if (!mounted) return;
      setState(() => _saving = false);
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.flat,
        title: const Text('Enregistrement impossible. Réessayez.'),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(size: 34),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                Text(
                  'Configurez votre espace',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pays, langue et devise — Abonex adapte ensuite '
                  'les fournisseurs suggérés à votre région.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                _StepHeader(index: 1, title: 'Pays', done: _country != null),
                const SizedBox(height: 10),
                DropdownButtonFormField<Country>(
                  initialValue: _country,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sélectionnez votre pays',
                    prefixIcon: Icon(LucideIcons.globe, size: 18),
                  ),
                  items: AppCountries.all
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c.name} — ${c.currency}'),
                        ),
                      )
                      .toList(),
                  onChanged: (c) {
                    if (c == null) return;
                    setState(() {
                      _country = c;
                      _currency = c.currency;
                      _language = c.languages.first;
                    });
                  },
                ),
                const SizedBox(height: 24),

                _StepHeader(
                  index: 2,
                  title: 'Langue de l\'application',
                  done: true,
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'fr', label: Text('Français')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {_language},
                  onSelectionChanged: (s) =>
                      setState(() => _language = s.first),
                ),
                const SizedBox(height: 24),

                _StepHeader(
                  index: 3,
                  title: 'Devise principale',
                  done: _country != null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration:
                      const InputDecoration(labelText: 'Devise principale'),
                  items: _allCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _currency = v!),
                ),
                const SizedBox(height: 8),
                Text(
                  'Déterminée par votre pays — les autres devises se '
                  'choisissent lors de la création d\'un abonnement.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                _StepHeader(
                  index: 4,
                  title: 'Votre rôle',
                  done: true,
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'owner',
                      label: Text('Propriétaire'),
                    ),
                    ButtonSegment(
                      value: 'manager',
                      label: Text('Gestionnaire'),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
                const SizedBox(height: 24),

                _StepHeader(
                  index: 5,
                  title: 'Inviter des collaborateurs (optionnel)',
                  done: _invites.isNotEmpty,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inviteController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'email@entreprise.com',
                          prefixIcon: Icon(LucideIcons.mail, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () {
                        final email = _inviteController.text.trim();
                        if (email.contains('@')) {
                          setState(() {
                            _invites.add((email: email, role: 'viewer'));
                            _inviteController.clear();
                          });
                        }
                      },
                      icon: const Icon(LucideIcons.plus, size: 18),
                    ),
                  ],
                ),
                if (_invites.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final invite in _invites)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(LucideIcons.userPlus, size: 18),
                      title: Text(invite.email),
                      subtitle: Text(switch (invite.role) {
                        'manager' => 'Gestionnaire',
                        'assistant' => 'Assistant',
                        _ => 'Lecteur',
                      }),
                      trailing: IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () =>
                            setState(() => _invites.remove(invite)),
                      ),
                    ),
                ],

                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _country == null || _saving ? null : _finish,
                  icon: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(LucideIcons.check, size: 18),
                  label: const Text('Terminer la configuration'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.index,
    required this.title,
    required this.done,
  });

  final int index;
  final String title;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: done
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          child: done
              ? Icon(LucideIcons.check,
                  size: 14, color: theme.colorScheme.onPrimary)
              : Text('$index', style: theme.textTheme.labelSmall),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
