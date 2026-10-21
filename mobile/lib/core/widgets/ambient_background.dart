import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fond d'ambiance : halos radiaux navy/émeraude très doux derrière
/// le contenu. Donne de la profondeur aux écrans "pleine page"
/// (login, inscription, onboarding) sans distraire —
/// la signature visuelle des apps fintech haut de gamme.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final alpha = dark ? 0.16 : 0.10;

    return Stack(
      children: [
        Positioned(
          top: -140,
          right: -100,
          child: _Glow(
            size: 340,
            color: AppColors.emerald.withValues(alpha: alpha),
          ),
        ),
        Positioned(
          bottom: -160,
          left: -120,
          child: _Glow(
            size: 380,
            color: AppColors.navy.withValues(alpha: dark ? 0.4 : 0.08),
          ),
        ),
        Positioned(
          top: MediaQuery.sizeOf(context).height * 0.4,
          left: -80,
          child: _Glow(
            size: 220,
            color: scheme.primary.withValues(alpha: alpha * 0.6),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
