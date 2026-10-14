import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_logo.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';

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
      body: SafeArea(
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
                      const SizedBox(height: 32),

                      // --- En-tête : marque + slogan ---
                      const Center(child: AppLogo()),
                      const SizedBox(height: 24),
                      Text(
                        'Bienvenue sur Abonex',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Connectez-vous pour piloter vos abonnements en toute sérénité.',
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
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'vous@entreprise.com',
                          prefixIcon: Icon(LucideIcons.mail, size: 20),
                        ),
                        validator: (value) =>
                            (value == null || !value.contains('@'))
                            ? 'Entrez un email valide'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
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
                            ? '8 caractères minimum'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _showForgotPasswordDialog(context),
                          child: const Text('Mot de passe oublié ?'),
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
                                : const Text('Se connecter'),
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Nouveau sur Abonex ?'),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            child: const Text('Créer un compte'),
                          ),
                        ],
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
                            'Connexion sécurisée',
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
        title: const Text('Réinitialiser le mot de passe'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'vous@entreprise.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
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
                  Ok() =>
                    'Si un compte existe pour cet email, un lien a été envoyé.',
                  Err(failure: final f) => f.message,
                }),
                autoCloseDuration: const Duration(seconds: 4),
              );
            },
            child: const Text('Envoyer'),
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
