import 'package:intl/intl.dart';

/// Formatage unique de l'app — montants en FCFA, dates en français.
/// Hand-roll pour les dates : pas de `initializeDateFormatting` requis.
abstract final class AppFormatters {
  static final _money = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  static String money(num value) => _money.format(value);

  static const _months = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  static const _monthsLong = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  static const _weekdays = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
  ];

  /// ex. `12 mars`
  static String dateShort(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  /// ex. `lundi 12 mars`
  static String dateLong(DateTime d) =>
      '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

  static String monthYear(DateTime d) =>
      '${_monthsLong[d.month - 1]} ${d.year}';

  /// "Dans 3 j" / "Aujourd'hui" / "En retard de 2 j"
  static String relativeDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    return switch (diff) {
      0 => "Aujourd'hui",
      1 => 'Demain',
      < 0 => 'En retard de ${-diff} j',
      _ => 'Dans $diff j',
    };
  }
}
