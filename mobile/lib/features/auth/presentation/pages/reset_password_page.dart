import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ambient_background.dart';

/// Réinitialisation du mot de passe : le lien reçu par email
/// (`abonex://reset/<uid>/<token>`) pré-remplit le formulaire via
/// le deep link ; il peut aussi être collé à la main.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, this.initialUid, this.initialToken});

  final String? initialUid;
  final String? initialToken;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _link;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final pre = (widget.initialUid != null && widget.initialToken != null)
        ? 'abonex://reset/${widget.initialUid}/${widget.initialToken}'
        : '';
    _link = TextEditingController(text: pre);
  }

  @override
  void dispose() {
    _link.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Extrait (uid, token) du lien `abonex://reset/<uid>/<token>`.
  /// Null si le format est invalide.
  (String, String)? get _extracted {
    final raw = _link.text.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.host == 'reset' && uri.pathSegments.length >= 2) {
      return (uri.pathSegments[0], uri.pathSegments[1]);
    }
    // Format nu "uid/token" toléré (copier-coller partiel).
    final parts = raw.split('/');
    if (parts.length == 2 && parts.every((p) => p.isNotEmpty)) {
      return (parts[0], parts[1]);
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final extracted = _extracted;
    if (extracted == null) {
      setState(() => _error = context.tr('reset.invalid'));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await getIt<Dio>().post<void>(
        ApiEndpoints.resetPassword,
        data: {
          'uid': extracted.$1,
          'token': extracted.$2,
          'password': _password.text,
        },
      );
      if (!mounted) return;
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.flat,
        title: Text(context.tr('reset.done')),
        autoCloseDuration: const Duration(seconds: 4),
      );
      context.go('/login');
    } on DioException catch (e) {
      setState(() {
        _submitting = false;
        _error = e.response?.data is Map
            ? ((e.response!.data as Map).values.first?.toString() ??
                  context.tr('reset.invalid'))
            : context.tr('reset.invalid');
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
                      Icon(
                        LucideIcons.keyRound,
                        size: 44,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('reset.title'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('reset.sub'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
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
                                AppTheme.radius - 4,
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.error,
                              ),
                            ),
                          ),
                        ),
                      TextFormField(
                        controller: _link,
                        decoration: InputDecoration(
                          labelText: context.tr('reset.link'),
                          hintText: context.tr('reset.linkHint'),
                          prefixIcon: const Icon(LucideIcons.link, size: 20),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? context.tr('reset.linkRequired')
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: context.tr('reset.newPassword'),
                          prefixIcon: const Icon(LucideIcons.lock, size: 20),
                        ),
                        validator: (v) => (v?.length ?? 0) >= 8
                            ? null
                            : context.tr('auth.passwordMin'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirm,
                        obscureText: true,
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
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : const Icon(LucideIcons.check, size: 18),
                        label: Text(context.tr('reset.submit')),
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
}
