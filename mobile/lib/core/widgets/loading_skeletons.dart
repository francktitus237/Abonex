import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../theme/app_theme.dart';

ShimmerEffect _skeletonEffect(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return ShimmerEffect(
    baseColor: dark ? const Color(0xFF253249) : const Color(0xFFE2E8F0),
    highlightColor: dark ? const Color(0xFF34425A) : const Color(0xFFF8FAFC),
    duration: const Duration(milliseconds: 1200),
  );
}

/// Squelettes de chargement réutilisables (skeletonizer).
/// Règle design : JAMAIS de spinner centré sur les listes —
/// on montre la structure de la page qui arrive.
class SkeletonListView extends StatelessWidget {
  const SkeletonListView({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      effect: _skeletonEffect(context),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => const _SkeletonRow(),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: const Row(
        children: [
          Bone.square(
            size: 44,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(width: 140),
                SizedBox(height: 6),
                Bone.text(width: 90, fontSize: 12),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Bone.text(width: 80),
              SizedBox(height: 6),
              Bone.text(width: 56, fontSize: 11),
            ],
          ),
        ],
      ),
    );
  }
}

/// Squelette de carte large (ex. carte de total du dashboard).
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 160});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      effect: _skeletonEffect(context),
      child: Bone(
        width: double.infinity,
        height: height,
        borderRadius: BorderRadius.circular(AppTheme.radius + 4),
      ),
    );
  }
}
