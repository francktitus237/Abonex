import 'package:flutter/material.dart';

/// Animation d'entrée légère : fondu + glissement de quelques pixels.
/// Style visé : sobre, presque imperceptible (comme Linear).
/// Utilise `delay` pour créer un effet cascade sur plusieurs widgets.
class AnimatedFadeIn extends StatefulWidget {
  const AnimatedFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;

  /// Délai avant le début de l'animation (effet cascade).
  final Duration delay;

  /// Décalage vertical de départ, en pixels.
  final double offset;

  final Duration duration;

  @override
  State<AnimatedFadeIn> createState() => _AnimatedFadeInState();
}

class _AnimatedFadeInState extends State<AnimatedFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  // easeOutCubic : démarre vite, décélère doucement — le rendu "fintech".
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
