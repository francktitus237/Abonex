import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';

/// Sélecteur de langue compact — globe + code courant (FR/EN).
/// Utilisable AVANT l'authentification : le choix applique la
/// langue immédiatement à toute l'app et la persiste.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  static const _locales = [
    ('fr', 'Français'),
    ('en', 'English'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (a, b) => a.locale != b.locale,
      builder: (context, settings) {
        final current = settings.locale.languageCode;
        return PopupMenuButton<String>(
          tooltip: current == 'fr' ? 'Langue' : 'Language',
          onSelected: (code) =>
              context.read<SettingsCubit>().setLocale(Locale(code)),
          itemBuilder: (_) => [
            for (final (code, label) in _locales)
              PopupMenuItem(
                value: code,
                child: Row(
                  children: [
                    Icon(
                      code == current
                          ? LucideIcons.circleCheck
                          : LucideIcons.circle,
                      size: 16,
                      color: code == current
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(label),
                  ],
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.languages,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  current.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  LucideIcons.chevronDown,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
