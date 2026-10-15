import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/models/auth_tokens_model.dart';
import '../../data/models/user_model.dart';

/// Acceptation d'invitation : l'invité colle le lien reçu par email,
/// définit son mot de passe, et entre directement dans l'espace
/// de travail de l'invitant avec le rôle assigné.
class InviteAcceptPage extends StatefulWidget {
  const InviteAcceptPage({super.key});

  @override
  State<InviteAcceptPage> createState() => _InviteAcceptPageState();
}

class _InviteAcceptPageState extends State<InviteAcceptPage> {
  final _formKey = GlobalKey<FormState>();
  final _token = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Le lien d'invitation est `abonex://invite/<token>` — on accepte
  /// le lien complet ou le token nu.
  String get _extractedToken {
    final raw = _token.text.trim();
    return raw.contains('/') ? raw.split('/').last : raw;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final res = await getIt<Dio>().post<Map<String, dynamic>>(
        ApiEndpoints.inviteAccept,
        data: {
          'token': _extractedToken,
          'password': _password.text,
          'first_name': _firstName.text.trim(),
          'last_name': _lastName.text.trim(),
        },
      );
      // Session identique au login : persiste tokens + user.
      final data = res.data!;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await getIt<AuthLocalDataSource>().saveSession(
        tokens: AuthTokensModel(
          access: data['access'] as String,
          refresh: data['refresh'] as String,
        ),
        user: user,
      );
      if (!mounted) return;
      getIt<AuthCubit>().onAuthenticated(user.toEntity());
      context.go('/');
    } on DioException catch (e) {
      setState(() {
        _submitting = false;
        _error = e.response?.data is Map
            ? ((e.response!.data as Map).values.first?.toString() ??
                'Lien d\'invitation invalide ou expiré.')
            : 'Lien d\'invitation invalide ou expiré.';
      });
    }
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
      ),
      body: SafeArea(
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
                    Icon(LucideIcons.mailCheck, size: 44,
                        color: scheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Rejoindre un espace de travail',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Collez le lien d\'invitation reçu par email '
                      'et choisissez votre mot de passe.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(
                                AppTheme.radius - 4),
                          ),
                          child: Text(_error!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.error)),
                        ),
                      ),
                    TextFormField(
                      controller: _token,
                      decoration: const InputDecoration(
                        labelText: 'Lien ou code d\'invitation',
                        hintText: 'abonex://invite/…',
                        prefixIcon: Icon(LucideIcons.link, size: 20),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Lien requis'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstName,
                            decoration: const InputDecoration(
                                labelText: 'Prénom'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastName,
                            decoration:
                                const InputDecoration(labelText: 'Nom'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(LucideIcons.lock, size: 20),
                      ),
                      validator: (v) => (v?.length ?? 0) >= 8
                          ? null
                          : '8 caractères minimum',
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: scheme.onPrimary),
                            )
                          : const Icon(LucideIcons.check, size: 18),
                      label: const Text('Rejoindre l\'espace'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
