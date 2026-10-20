import 'dart:math' as math;

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
      art: _Art.expenses,
      badge: 'Suivi des dépenses',
      title: 'Maîtrisez chaque franc\ndépensé',
      description:
          'Abonex centralise vos abonnements, factures, loyers et salaires '
          '— entreprise ou foyer, vous savez toujours où va votre argent.',
    ),
    _OnboardingData(
      art: _Art.reminders,
      badge: 'Rappels intelligents',
      title: 'Zéro échéance\noubliée',
      description:
          'Rappels automatiques avant chaque paiement, alerte plein écran '
          'le jour J : ne payez plus jamais de pénalité de retard.',
    ),
    _OnboardingData(
      art: _Art.team,
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
                            art: page.art,
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

enum _Art { expenses, reminders, team }

class _OnboardingData {
  const _OnboardingData({
    required this.art,
    required this.badge,
    required this.title,
    required this.description,
  });

  final _Art art;
  final String badge;
  final String title;
  final String description;
}

// ---------------------------------------------------------------------------
// Illustration : fond navy + dessin vectoriel adapté au texte de la slide,
// badge émeraude flottant en bas à droite.
// ---------------------------------------------------------------------------

const _navy = AppColors.navy;
const _navy2 = Color(0xFF173A7A);
const _orange = Color(0xFFF59E0B);
const _red = Color(0xFFEF4444);
const _blue = Color(0xFF3B82F6);
const _gold = Color(0xFFF5B72E);
const _grey = Color(0xFF64748B);

class _Illustration extends StatelessWidget {
  const _Illustration({required this.art, required this.badge});

  final _Art art;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radius + 12);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: radius,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_navy2, _navy],
                ),
              ),
              child: Stack(
                children: [
                  // Halo émeraude décoratif.
                  Positioned(
                    top: -80,
                    right: -80,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.emerald.withValues(alpha: 0.40),
                            AppColors.emerald.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 360,
                        height: 360,
                        child: switch (art) {
                          _Art.expenses => const _ExpensesArt(),
                          _Art.reminders => const _RemindersArt(),
                          _Art.team => const _TeamArt(),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -12,
          right: 20,
          child: _FloatingBadge(badge: badge),
        ),
      ],
    );
  }
}

TextStyle _t(double size, FontWeight w, Color c) =>
    TextStyle(fontSize: size, fontWeight: w, color: c, height: 1.1);

BoxDecoration _cardDeco(double radius) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.22),
      blurRadius: 26,
      offset: const Offset(0, 12),
    ),
  ],
);

// ---------- 1. Suivi des dépenses ----------
class _ExpensesArt extends StatelessWidget {
  const _ExpensesArt();

  @override
  Widget build(BuildContext context) {
    const legend = [
      ('Abonnements', AppColors.emerald),
      ('Loyers', _blue),
      ('Salaires', _orange),
      ('Factures', _red),
    ];
    return Stack(
      children: [
        Positioned(
          left: 38,
          top: 50,
          width: 284,
          height: 250,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: _cardDeco(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dépenses du mois', style: _t(14, FontWeight.w600, _grey)),
                const SizedBox(height: 6),
                Text('1 250 000', style: _t(38, FontWeight.w800, _navy)),
                const SizedBox(height: 2),
                Text(
                  'FCFA',
                  style: _t(16, FontWeight.w800, AppColors.lightPrimary),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: CustomPaint(
                          painter: _DonutPainter(),
                          child: Center(
                            child: Text(
                              '100 %',
                              style: _t(13, FontWeight.w800, _navy),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (label, color) in legend)
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    label,
                                    style: _t(13, FontWeight.w600, _navy),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Pièce dorée « F ».
        Positioned(
          right: 14,
          top: 26,
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _gold,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.65),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text('F', style: _t(28, FontWeight.w800, Colors.white)),
          ),
        ),
        // Pastille « Payé ».
        Positioned(
          left: 34,
          top: 312,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.emerald,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_rounded, size: 18, color: _navy),
                const SizedBox(width: 6),
                Text('Payé', style: _t(14, FontWeight.w800, _navy)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    const segments = [
      (0.40, AppColors.emerald),
      (0.25, _blue),
      (0.20, _orange),
      (0.15, _red),
    ];
    var start = -math.pi / 2;
    for (final (share, color) in segments) {
      final sweep = 2 * math.pi * share;
      canvas.drawArc(
        rect,
        start,
        sweep - 0.06,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------- 2. Rappels intelligents ----------
class _RemindersArt extends StatelessWidget {
  const _RemindersArt();

  @override
  Widget build(BuildContext context) {
    const weeks = [
      [13, 14, 15, 16, 17, 18, 19],
      [20, 21, 22, 23, 24, 25, 26],
      [27, 28, 29, 30, 31, 1, 2],
    ];
    const letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    Widget cell(Widget child) => Expanded(child: Center(child: child));

    return Stack(
      children: [
        // Calendrier.
        Positioned(
          left: 50,
          top: 44,
          width: 260,
          height: 182,
          child: Container(
            decoration: _cardDeco(24),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  height: 38,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF34D399), AppColors.lightPrimary],
                    ),
                  ),
                  child: Text(
                    'OCTOBRE',
                    style: _t(16, FontWeight.w800, Colors.white),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          children: [
                            for (final l in letters)
                              cell(Text(l, style: _t(11, FontWeight.w700, _grey))),
                          ],
                        ),
                        for (final week in weeks)
                          Row(
                            children: [
                              for (final d in week)
                                cell(
                                  d == 25
                                      ? Container(
                                          width: 26,
                                          height: 26,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            color: _orange,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '$d',
                                            style: _t(
                                              12,
                                              FontWeight.w800,
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          '$d',
                                          style: _t(
                                            12,
                                            FontWeight.w600,
                                            (d < 10)
                                                ? const Color(0xFFCBD5E1)
                                                : _navy,
                                          ),
                                        ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Cloche avec badge.
        Positioned(
          right: 18,
          top: 22,
          child: SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: _navy,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text('1', style: _t(12, FontWeight.w800, Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Notification « Loyer demain ».
        Positioned(
          left: 60,
          top: 238,
          width: 240,
          height: 58,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: _cardDeco(18),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: _orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Loyer demain', style: _t(17, FontWeight.w800, _navy)),
                    const SizedBox(height: 4),
                    Text('150 000 FCFA', style: _t(13, FontWeight.w600, _grey)),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Alerte « Échéance du jour ».
        Positioned(
          left: 80,
          top: 306,
          width: 200,
          height: 42,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: _cardDeco(14),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: _red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Échéance du jour',
                  style: _t(14, FontWeight.w800, _navy),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- 3. Équipe & sécurité ----------
class _TeamArt extends StatelessWidget {
  const _TeamArt();

  @override
  Widget build(BuildContext context) {
    Widget avatar({
      required double cx,
      required Color shirt,
      required Color badgeColor,
      required IconData badgeIcon,
    }) {
      return Positioned(
        left: cx - 38,
        top: 252,
        width: 76,
        height: 76,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEF7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Icon(Icons.person_rounded, size: 46, color: shirt),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: Icon(badgeIcon, size: 15, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Lignes pointillées bouclier → membres.
        Positioned.fill(child: CustomPaint(painter: _DottedLinesPainter())),
        // Halo derrière le bouclier.
        Positioned(
          left: 60,
          top: 0,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.emerald.withValues(alpha: 0.35),
                  AppColors.emerald.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        // Bouclier.
        const Positioned(
          left: 0,
          right: 0,
          top: 30,
          child: Icon(
            Icons.verified_user_rounded,
            size: 170,
            color: AppColors.emerald,
          ),
        ),
        // Cadenas.
        Positioned(
          right: 40,
          top: 40,
          child: Container(
            width: 50,
            height: 50,
            decoration: _cardDeco(15),
            child: const Icon(Icons.lock_rounded, color: _navy, size: 26),
          ),
        ),
        // Membres : propriétaire, gestionnaire, lecteur.
        avatar(
          cx: 95,
          shirt: AppColors.lightPrimary,
          badgeColor: _gold,
          badgeIcon: Icons.workspace_premium_rounded,
        ),
        avatar(
          cx: 180,
          shirt: _blue,
          badgeColor: AppColors.lightPrimary,
          badgeIcon: Icons.edit_rounded,
        ),
        avatar(
          cx: 265,
          shirt: _orange,
          badgeColor: _blue,
          badgeIcon: Icons.visibility_rounded,
        ),
      ],
    );
  }
}

class _DottedLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    const from = Offset(180, 190);
    for (final x in const [95.0, 180.0, 265.0]) {
      final to = Offset(x, 258);
      final delta = to - from;
      final steps = (delta.distance / 9).floor();
      for (var i = 1; i < steps; i++) {
        canvas.drawCircle(from + delta * (i / steps), 1.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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