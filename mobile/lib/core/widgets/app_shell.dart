import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../di/injection.dart';
import '../l10n/app_strings.dart';
import '../storage/settings_storage.dart';

/// Coquille de navigation basse — les 5 onglets du cahier des charges :
/// Accueil · Abonnements · Calendrier · Rapports · Profil.
///
/// Barre flottante "pill" : cartes arrondies, ombre douce, icône
/// active sur pastille émeraude — style fintech moderne.
/// StatefulShellNavigationShell garde l'état de chaque branche
/// (scroll, formulaires…) quand on change d'onglet.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _items = [
    (icon: LucideIcons.house, label: 'nav.home'),
    (icon: LucideIcons.repeat, label: 'nav.subscriptions'),
    (icon: LucideIcons.calendar, label: 'nav.calendar'),
    (icon: LucideIcons.chartColumn, label: 'nav.reports'),
    (icon: LucideIcons.user, label: 'nav.profile'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstLoginGuide());
  }

  Future<void> _showFirstLoginGuide() async {
    final storage = getIt<SettingsStorage>();
    if (storage.firstLoginGuideSeen || !mounted) return;
    await storage.setFirstLoginGuideSeen();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FirstLoginGuide(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Le contenu passe SOUS la barre flottante — les pages
      // ont déjà un padding bas dans leurs ListView.
      extendBody: true,
      body: Padding(
        padding: EdgeInsets.only(
          bottom: 92 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: widget.shell,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.4
                        : 0.10,
                  ),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < _items.length; i++)
                  _NavItem(
                    icon: _items[i].icon,
                    label: context.tr(_items[i].label),
                    selected: i == widget.shell.currentIndex,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.shell.goBranch(
                        i,
                        // Re-taper l'onglet actif ramène à sa racine
                        // (comportement standard des apps fintech).
                        initialLocation: i == widget.shell.currentIndex,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Item de navigation : icône sur pastille animée + label.
/// La pastille s'anime en largeur à la sélection.
class _FirstLoginGuide extends StatefulWidget {
  const _FirstLoginGuide();

  @override
  State<_FirstLoginGuide> createState() => _FirstLoginGuideState();
}

class _FirstLoginGuideState extends State<_FirstLoginGuide> {
  final _controller = PageController();
  int _index = 0;

  static const _steps = [
    (
      icon: LucideIcons.layoutDashboard,
      title: 'guide.1.title',
      description: 'guide.1.desc',
    ),
    (
      icon: LucideIcons.circlePlus,
      title: 'guide.2.title',
      description: 'guide.2.desc',
    ),
    (
      icon: LucideIcons.calendarCheck,
      title: 'guide.3.title',
      description: 'guide.3.desc',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = _index == _steps.length - 1;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    context.tr('guide.badge'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.tr('guide.skip')),
                ),
              ],
            ),
            SizedBox(
              height: 250,
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (_, index) {
                  final step = _steps[index];
                  return AnimatedScale(
                    scale: index == _index ? 1 : 0.92,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                scheme.primary,
                                scheme.primary.withValues(alpha: 0.68),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(
                            step.icon,
                            color: scheme.onPrimary,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.tr(step.title),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          context.tr(step.description),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: index == _index ? 24 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == _index
                        ? scheme.primary
                        : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                if (last) {
                  Navigator.of(context).pop();
                } else {
                  _controller.nextPage(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
              icon: Icon(last ? LucideIcons.check : LucideIcons.arrowRight),
              label: Text(context.tr(last ? 'guide.done' : 'guide.next')),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}