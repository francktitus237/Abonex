import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/data/countries.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/ambient_background.dart';
import '../../../../core/widgets/app_logo.dart';
import '../cubit/auth_cubit.dart';
import '../widgets/language_button.dart';

/// Inscription réelle : POST /auth/register/ via AuthCubit.
/// En cas de succès, la session démarre et le router
/// redirige automatiquement vers l'accueil.
/// Rendu instantané, sans animations décoratives.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _accepted = false;
  bool _submitting = false;
  String? _error;
  // Type de compte : personnel (usage individuel) ou
  // entreprise (employés, rôles, masse salariale).
  bool _businessAccount = false;
  // Pays de l'utilisateur — pré-rempli depuis la locale du
  // téléphone ; détermine devise/langue côté serveur.
  late Country _country = _detectCountry();

  static Country _detectCountry() {
    final code = WidgetsBinding.instance.platformDispatcher.locale.countryCode
        ?.toUpperCase();
    return AppCountries.all.firstWhere(
      (c) => c.code == code,
      orElse: () => AppCountries.all.firstWhere((c) => c.code == 'CM'),
    );
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_accepted) {
      setState(() => _error = context.tr('auth.acceptTerms'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final result = await context.read<AuthCubit>().register(
      email: _email.text.trim(),
      password: _password.text,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      country: _country.code,
      kind: _businessAccount ? 'business' : 'personal',
    );

    // Le router gère la redirection sur Authenticated — ici on
    // n'affiche une erreur que si la session n'a pas démarré.
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (result case Err(failure: final f)) {
        _error = switch (f) {
          ValidationFailure(:final fieldErrors) =>
            fieldErrors.values.firstOrNull ?? f.localizedMessage,
          _ => f.localizedMessage,
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/login'),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: LanguageButton()),
          ),
        ],
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: AppLogo(size: 52)),
                      const SizedBox(height: 24),
                      Text(
                        context.tr('auth.createTitle'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('auth.createSub'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Type de compte ---
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                            value: false,
                            icon: const Icon(LucideIcons.user, size: 17),
                            label: Text(context.tr('auth.personal')),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: const Icon(LucideIcons.building2, size: 17),
                            label: Text(context.tr('auth.business')),
                          ),
                        ],
                        selected: {_businessAccount},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) =>
                            setState(() => _businessAccount = s.first),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr(
                          _businessAccount
                              ? 'auth.businessHint'
                              : 'auth.personalHint',
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // --- Erreur serveur ---
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: _error == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.error.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radius - 4,
                                    ),
                                    border: Border.all(
                                      color: scheme.error.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        LucideIcons.circleAlert,
                                        size: 18,
                                        color: scheme.error,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: scheme.error),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstName,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.givenName],
                              decoration: InputDecoration(
                                labelText: context.tr('profile.firstName'),
                                prefixIcon: const Icon(
                                  LucideIcons.user,
                                  size: 20,
                                ),
                              ),
                              validator: _required,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lastName,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.familyName],
                              decoration: InputDecoration(
                                labelText: context.tr('profile.lastName'),
                              ),
                              validator: _required,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: context.tr('auth.emailPro'),
                          hintText: context.tr('auth.emailHint'),
                          prefixIcon: const Icon(LucideIcons.mail, size: 20),
                        ),
                        validator: (v) => v != null && v.contains('@')
                            ? null
                            : context.tr('auth.emailInvalid'),
                      ),
                      const SizedBox(height: 14),
                      // Pays → détermine automatiquement la devise
                      // locale et la langue côté serveur.
                      DropdownButtonFormField<Country>(
                        initialValue: _country,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.tr('auth.country'),
                          helperText: context.tr('auth.countryHelper', {
                            'currency': _country.currency,
                          }),
                          prefixIcon: const Icon(LucideIcons.globe, size: 20),
                        ),
                        items: AppCountries.all
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  '${c.nameFor(AppFormatters.lang)} — ${c.currency}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (c) {
                          if (c != null) setState(() => _country = c);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: context.tr('auth.password'),
                          prefixIcon: const Icon(LucideIcons.lock, size: 20),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                              size: 20,
                            ),
                          ),
                        ),
                        validator: (v) => (v?.length ?? 0) >= 8
                            ? null
                            : context.tr('auth.passwordMin'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirm,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: context.tr('auth.confirmPassword'),
                          prefixIcon: const Icon(
                            LucideIcons.lockKeyhole,
                            size: 20,
                          ),
                        ),
                        validator: (v) => v == _password.text
                            ? null
                            : context.tr('auth.passwordMismatch'),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _accepted,
                        onChanged: (v) =>
                            setState(() => _accepted = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(context.tr('auth.terms')),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : const Icon(LucideIcons.userPlus, size: 19),
                        label: Text(
                          _submitting
                              ? context.tr('auth.creating')
                              : context.tr('auth.create'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.shieldCheck,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.tr('auth.dataSecure'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? context.tr('common.required') : null;
}
