import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/app_strings.dart';
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

  List<_OnboardingData> _pages(BuildContext context) => [
    _OnboardingData(
      art: _Art.expenses,
      badge: context.tr('onb.1.badge'),
      title: context.tr('onb.1.title'),
      description: context.tr('onb.1.desc'),
    ),
    _OnboardingData(
      art: _Art.reminders,
      badge: context.tr('onb.2.badge'),
      title: context.tr('onb.2.title'),
      description: context.tr('onb.2.desc'),
    ),
    _OnboardingData(
      art: _Art.team,
      badge: context.tr('onb.3.badge'),
      title: context.tr('onb.3.title'),
      description: context.tr('onb.3.desc'),
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

    final pages = _pages(context);

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
                  TextButton(
                    onPressed: _finish,
                    child: Text(context.tr('onb.skip')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final page = pages[index];
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
                      pages.length,
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
                      if (_index == pages.length - 1) {
                        _finish();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    icon: Icon(
                      _index == pages.length - 1
                          ? LucideIcons.check
                          : LucideIcons.arrowRight,
                    ),
                    label: Text(
                      _index == pages.length - 1
                          ? context.tr('onb.start')
                          : context.tr('onb.next'),
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
        Positioned(bottom: -12, right: 20, child: _FloatingBadge(badge: badge)),
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

/// Élément flottant : flotte doucement en continu (flottement
/// vertical sinusoïdal + légère rotation optionnelle).
class _Floaty extends StatefulWidget {
  const _Floaty({
    required this.child,
    this.phase = 0,
    this.amplitude = 6,
    this.rotation = 0,
  });

  final Widget child;
  final double phase;
  final double amplitude;
  final double rotation;

  @override
  State<_Floaty> createState() => _FloatyState();
}

class _FloatyState extends State<_Floaty>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value * 2 * math.pi + widget.phase;
        return Transform.translate(
          offset: Offset(0, math.sin(t) * widget.amplitude),
          child: Transform.rotate(
            angle: widget.rotation * math.sin(t),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Cloche qui « sonne » : balancement périodique répété.
class _WigglyBell extends StatefulWidget {
  const _WigglyBell();

  @override
  State<_WigglyBell> createState() => _WigglyBellState();
}

class _WigglyBellState extends State<_WigglyBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        // Secousse par salves : sinus amorti qui repart à 0.
        final t = _c.value;
        final wobble = t < 0.5
            ? math.sin(t * 4 * math.pi) * (1 - t * 2) * 0.16
            : 0.0;
        return Transform.rotate(angle: wobble, child: child);
      },
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: _navy,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.notifications_active_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

/// Pastille de devise flottante (« FCFA », « € », « $ »).
class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        style: _t(14, FontWeight.w800, Colors.white),
      ),
    );
  }
}

// ---------- 1. Tout-en-un : héros du dashboard + tuiles ----------
class _ExpensesArt extends StatelessWidget {
  const _ExpensesArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Carte héros : réplique miniature du vrai dashboard —
        // « Reste à payer » + barre de progression.
        Positioned(
          left: 30,
          top: 34,
          width: 300,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B1F44), Color(0xFF1B4184)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('dash.toPay').toUpperCase(),
                  style: _t(12, FontWeight.w700, const Color(0xFF7DD3B0)),
                ),
                const SizedBox(height: 6),
                Text(
                  '1 250 000 FCFA',
                  style: _t(34, FontWeight.w800, Colors.white),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Container(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        FractionallySizedBox(
                          widthFactor: 0.62,
                          child: Container(color: AppColors.emerald),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '62 %',
                  style: _t(
                    12,
                    FontWeight.w700,
                    Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Tuile abonnement — style des vraies cartes de la liste.
        Positioned(
          left: 52,
          top: 196,
          width: 256,
          child: _MiniTile(
            icon: LucideIcons.clapperboard,
            color: _red,
            name: 'Netflix',
            trailing: '15,99 €',
          ),
        ),
        Positioned(
          left: 66,
          top: 252,
          width: 256,
          child: _MiniTile(
            icon: LucideIcons.house,
            color: _blue,
            name: context.tr('onb.rent'),
            trailing: '150 000 FCFA',
          ),
        ),
        // Devises flottantes — l'app additionne même multi-devises.
        const Positioned(
          right: 16,
          top: 20,
          child: _Floaty(
            amplitude: 7,
            child: _CurrencyChip(label: '€', color: _gold),
          ),
        ),
        const Positioned(
          right: 6,
          top: 128,
          child: _Floaty(
            phase: 2.1,
            amplitude: 5,
            child: _CurrencyChip(label: '\$', color: _blue),
          ),
        ),
        const Positioned(
          left: 8,
          top: 150,
          child: _Floaty(
            phase: 4.2,
            amplitude: 6,
            child: _CurrencyChip(label: 'FCFA', color: AppColors.emerald),
          ),
        ),
        // Pastille « Payé ».
        Positioned(
          left: 60,
          top: 318,
          child: _Floaty(
            phase: 1.2,
            amplitude: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: AppColors.emerald,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emerald.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: _navy,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('status.paid'),
                    style: _t(14, FontWeight.w800, _navy),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tuile façon « prochaine échéance » : icône catégorie + nom +
/// montant, comme dans la vraie liste.
class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.icon,
    required this.color,
    required this.name,
    required this.trailing,
  });

  final IconData icon;
  final Color color;
  final String name;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: _cardDeco(16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _t(16, FontWeight.w700, _navy),
            ),
          ),
          Text(trailing, style: _t(15, FontWeight.w800, _navy)),
        ],
      ),
    );
  }
}

// ---------- 2. Rappels qui insistent + alarme ----------
class _RemindersArt extends StatelessWidget {
  const _RemindersArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Cloche animée en haut à droite — l'alarme « sonne ».
        const Positioned(right: 22, top: 18, child: _WigglyBell()),
        // Badge rouge de compteur sur la cloche.
        Positioned(
          right: 18,
          top: 14,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text('3', style: _t(12, FontWeight.w800, Colors.white)),
          ),
        ),
        // Grande heure — l'alarme plein écran du jour J.
        Positioned(
          left: 46,
          top: 30,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 14,
            ),
            decoration: _cardDeco(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '09:00',
                  style: _t(42, FontWeight.w800, _navy),
                ),
                Text(
                  context.tr('onb.dueToday').toUpperCase(),
                  style: _t(11, FontWeight.w800, _red),
                ),
              ],
            ),
          ),
        ),
        // Escalade des rappels — de plus en plus insistants.
        Positioned(
          left: 34,
          top: 148,
          width: 252,
          child: _ReminderCard(
            when: 'J-7',
            label: 'Netflix',
            detail: '15,99 €',
            color: _grey,
          ),
        ),
        Positioned(
          left: 48,
          top: 210,
          width: 262,
          child: _ReminderCard(
            when: 'J-1',
            label: context.tr('onb.rentTomorrow'),
            detail: '150 000 FCFA',
            color: _orange,
          ),
        ),
        Positioned(
          left: 62,
          top: 272,
          width: 272,
          child: _ReminderCard(
            when: context.tr('onb.dueToday'),
            label: context.tr('onb.dueNow'),
            detail: '',
            color: _red,
            alarm: true,
          ),
        ),
      ],
    );
  }
}

/// Carte notification de l'escalade — plus le jour approche,
/// plus la couleur chauffe (gris → orange → rouge alarme).
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.when,
    required this.label,
    required this.detail,
    required this.color,
    this.alarm = false,
  });

  final String when;
  final String label;
  final String detail;
  final Color color;
  final bool alarm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: alarm
            ? Border.all(color: _red, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: alarm
                ? _red.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: alarm ? 20 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              alarm
                  ? Icons.alarm_rounded
                  : Icons.notifications_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(
                    15,
                    FontWeight.w800,
                    alarm ? _red : _navy,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(detail, style: _t(12, FontWeight.w600, _grey)),
              ],
            ),
          ),
          Text(when, style: _t(12, FontWeight.w800, color)),
        ],
      ),
    );
  }
}

// ---------- 3. Intelligence : doublons, tarifs, reste à vivre ----------
class _TeamArt extends StatelessWidget {
  const _TeamArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Halo émeraude derrière la carte.
        Positioned(
          left: 40,
          top: 20,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.emerald.withValues(alpha: 0.3),
                  AppColors.emerald.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        // Carte « Optimiser votre budget » — la vraie feature.
        Positioned(
          left: 34,
          top: 46,
          width: 292,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: _cardDeco(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.sparkles,
                      size: 17,
                      color: AppColors.lightPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('ins.title'),
                      style: _t(15, FontWeight.w800, _navy),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Doublon détecté — alerte rouge.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.copy_all_rounded,
                        size: 15,
                        color: _red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '2× Netflix — ${context.tr('ins.dupWord')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(13, FontWeight.w700, _red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Alternative moins chère — économie verte.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.trendingDown,
                        size: 15,
                        color: AppColors.emerald,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Canal+ Essentiel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(13, FontWeight.w700, _navy),
                        ),
                      ),
                      Text(
                        '−5,01 €',
                        style: _t(
                          14,
                          FontWeight.w800,
                          AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                // Reste à vivre — la promesse du boss.
                Text(
                  context.tr('ins.restLabel'),
                  style: _t(12, FontWeight.w600, _grey),
                ),
                const SizedBox(height: 2),
                Text(
                  '820 € / mois',
                  style: _t(26, FontWeight.w800, AppColors.lightPrimary),
                ),
              ],
            ),
          ),
        ),
        // Étincelles flottantes — le côté « magique » de l'IA.
        const Positioned(
          right: 30,
          top: 26,
          child: _Floaty(
            amplitude: 6,
            rotation: 0.15,
            child: Icon(
              LucideIcons.sparkles,
              size: 34,
              color: _gold,
            ),
          ),
        ),
        const Positioned(
          left: 18,
          top: 150,
          child: _Floaty(
            phase: 3.1,
            amplitude: 5,
            rotation: -0.12,
            child: Icon(
              LucideIcons.sparkle,
              size: 24,
              color: AppColors.emerald,
            ),
          ),
        ),
        // Pastille « économie » qui flotte.
        Positioned(
          right: 44,
          top: 288,
          child: _Floaty(
            phase: 1.8,
            amplitude: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: AppColors.emerald,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emerald.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                '−30 €/mois',
                style: _t(14, FontWeight.w800, _navy),
              ),
            ),
          ),
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
          const Icon(LucideIcons.check, size: 14, color: Color(0xFF0B1F44)),
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
