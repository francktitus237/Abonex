import 'package:flutter/foundation.dart';

/// Signal « re-tap sur l'onglet actif » — diffusé par AppShell
/// quand l'utilisateur retouche l'icône de l'onglet courant.
/// Chaque page écoute [tick] et, si [lastIndex] la vise,
/// remonte en haut de sa liste et rafraîchit ses données.
class TabReselect {
  /// Compteur qui change à chaque re-tap (même valeur d'index
  /// répétée → nouvelle notification quand même).
  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  /// Index de l'onglet concerné par le dernier re-tap.
  int lastIndex = -1;

  void fire(int index) {
    lastIndex = index;
    tick.value++;
  }
}
