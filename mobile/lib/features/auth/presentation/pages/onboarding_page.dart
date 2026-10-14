import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/storage/settings_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    _OnboardingData(
      image: 'assets/onboarding/onboarding_1.jpg',
      badge: 'Suivi des dépenses',
      title: 'Maîtrisez chaque franc\ndépensé',
      description:
          'Abonex centralise vos abonnements, factures, loyers et salaires '
          '— entreprise ou foyer, vous savez toujours où va votre argent.',
    ),
    _OnboardingData(
      image: 'assets/onboarding/onboarding_2.jpg',
      badge: 'Rappels intelligents',
      title: 'Zéro échéance\noubliée',
      description:
          'Rappels automatiques avant chaque paiement, alerte plein écran '
          'le jour J : ne payez plus jamais de pénalité de retard.',
    ),
    _OnboardingData(
      image: 'assets/onboarding/onboarding_3.jpg',
      badge: 'Équipe & sécurité',
      title: 'Collaborez en toute\nsérénité',
      description:
          'Invitez vos collaborateurs avec des rôles précis : chacun voit '
          'et fait exactement ce que vous avez décidé.',
    ),
  ];

  Future<void> _finish() async {
    await getIt<SettingsStorage>().setOnboardingSeen();
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppLogo(size: 42),
                  TextButton(onPressed: _finish, child: const Text('Passer')),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Expanded(
                          flex: 5,
                          child: _Illustration(
                            image: page.image,
                            badge: page.badge,
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Text(
                            page.description,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: index == _index ? 28 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index == _index
                              ? scheme.primary
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () {
                      if (_index == _pages.length - 1) {
                        _finish();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    icon: Icon(
                      _index == _pages.length - 1
                          ? LucideIcons.check
                          : LucideIcons.arrowRight,
                    ),
                    label: Text(
                      _index == _pages.length - 1 ? 'Commencer' : 'Continuer',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.image,
    required this.badge,
    required this.title,
    required this.description,
  });

  final String image;
  final String badge;
  final String title;
  final String description;
}

/// Illustration d'onboarding : photo professionnelle recadrée,
/// voile navy en bas + badge émeraude flottant.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.image, required this.badge});

  final String image;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Photo pro en plein cadre, coins très arrondis.
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius + 12),
            child: Image.asset(image, fit: BoxFit.cover),
          ),
        ),
        // Voile navy en bas pour la lisibilité du badge.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius + 12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF0B1F44).withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
        ),
        // Badge "verre" qui déborde du cadre — touche premium.
        Positioned(
          bottom: -12,
          right: 20,
          child: _FloatingBadge(badge: badge),
        ),
      ],
    );
  }
}

/// Badge émeraude flottant sous l'image.
class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({required this.badge});

  final String badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.emerald,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.check,
            size: 14,
            color: Color(0xFF0B1F44),
          ),
          const SizedBox(width: 6),
          Text(
            badge,
            style: const TextStyle(
              color: Color(0xFF0B1F44),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
