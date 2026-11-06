import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/ambient_background.dart';
import '../../../../core/widgets/app_logo.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';
import '../widgets/language_button.dart';

/// Écran de connexion. Le widget ne contient AUCUNE logique métier :
/// la validation de forme est locale, tout le reste est dans LoginCubit.
/// Pas d'animations décoratives : rendu instantané, style production.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Le cubit du formulaire est créé avec la page et détruit avec elle.
    return BlocProvider(
      create: (_) => getIt<LoginCubit>(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    // Valide les champs localement AVANT de frapper l'API.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    context.read<LoginCubit>().submit(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              // Largeur max : propre aussi sur tablette / web / grand écran.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        // Langue modifiable AVANT connexion — le choix
                        // s'applique à l'app entière immédiatement.
                        const Align(
                          alignment: Alignment.centerRight,
                          child: LanguageButton(),
                        ),
                        const SizedBox(height: 12),

                        // --- En-tête : marque + slogan ---
                        const Center(child: AppLogo()),
                        const SizedBox(height: 24),
                        Text(
                          context.tr('auth.welcome'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('auth.loginSub'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // --- Bandeau d'erreur animé ---
                        BlocBuilder<LoginCubit, LoginState>(
                          builder: (context, state) {
                            return AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              child: switch (state) {
                                LoginFailure(:final message) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _ErrorBanner(message: message),
                                ),
                                _ => const SizedBox.shrink(),
                              },
                            );
                          },
                        ),

                        // --- Champs ---
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: context.tr('common.email'),
                            hintText: context.tr('auth.emailHint'),
                            prefixIcon: const Icon(LucideIcons.mail, size: 20),
                          ),
                          validator: (value) =>
                              (value == null || !value.contains('@'))
                              ? context.tr('auth.emailInvalid')
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: context.tr('auth.password'),
                            prefixIcon: const Icon(LucideIcons.lock, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? LucideIcons.eye
                                    : LucideIcons.eyeOff,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              (value == null || value.length < 8)
                              ? context.tr('auth.passwordMin')
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _showForgotPasswordDialog(context),
                            child: Text(context.tr('auth.forgot')),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // --- Bouton de connexion ---
                        BlocBuilder<LoginCubit, LoginState>(
                          builder: (context, state) {
                            final submitting = state is LoginSubmitting;
                            return ElevatedButton(
                              onPressed: submitting ? null : _submit,
                              child: submitting
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.onPrimary,
                                      ),
                                    )
                                  : Text(context.tr('auth.login')),
                            );
                          },
                        ),

                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(context.tr('auth.newHere')),
                            TextButton(
                              onPressed: () => context.go('/register'),
                              child: Text(context.tr('auth.createAccount')),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => context.go('/invite'),
                          child: Text(context.tr('auth.haveInvite')),
                        ),
                        const SizedBox(height: 16),

                        // --- Mention de confiance ---
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
                              context.tr('auth.secure'),
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
      ),
    );
  }

  /// Dialogue "mot de passe oublié" — P1 du CDC.
  void _showForgotPasswordDialog(BuildContext context) {
    final cubit = context.read<LoginCubit>();
    final emailController = TextEditingController(text: _emailController.text);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          LucideIcons.mail,
          color: Theme.of(dialogContext).colorScheme.primary,
        ),
        title: Text(dialogContext.tr('auth.resetTitle')),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: InputDecoration(
            labelText: dialogContext.tr('common.email'),
            hintText: dialogContext.tr('auth.emailHint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // L'utilisateur a déjà reçu le lien par email →
              // directement vers le formulaire de nouveau mot de passe.
              Navigator.of(dialogContext).pop();
              context.push('/reset-password');
            },
            child: Text(dialogContext.tr('reset.haveLink')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final email = emailController.text.trim();
              Navigator.of(dialogContext).pop();
              if (!email.contains('@')) return;

              final result = await cubit.forgotPassword(email);
              if (!context.mounted) return;

              // Message volontairement identique quel que soit le résultat
              // serveur : on ne révèle pas si l'email existe en base.
              toastification.show(
                context: context,
                type: switch (result) {
                  Ok() => ToastificationType.success,
                  Err() => ToastificationType.error,
                },
                style: ToastificationStyle.flat,
                title: Text(switch (result) {
                  Ok() => context.tr('auth.resetSent'),
                  Err(failure: final f) => f.localizedMessage,
                }),
                autoCloseDuration: const Duration(seconds: 4),
              );
            },
            child: Text(dialogContext.tr('common.send')),
          ),
        ],
      ),
    );
  }
}

/// Bandeau d'erreur du formulaire — rouge doux, icône, message.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius - 4),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.circleAlert,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
