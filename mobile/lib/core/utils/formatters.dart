import 'package:intl/intl.dart';

/// Formatage unique de l'app — montants en FCFA, dates en français.
/// Hand-roll pour les dates : pas de `initializeDateFormatting` requis.
abstract final class AppFormatters {
  /// Symboles par code ISO 4217 — couvre les devises des pays cibles.
  static const _symbols = {
    'XAF': 'FCFA', 'XOF': 'FCFA', 'EUR': '€', 'USD': '\$',
    'GBP': '£', 'CHF': 'CHF', 'CAD': '\$', 'MAD': 'DH',
    'DZD': 'DA', 'TND': 'DT', 'NGN': '₦', 'GHS': '₵',
    'KES': 'KSh', 'ZAR': 'R', 'INR': '₹', 'CNY': '¥',
    'JPY': '¥', 'SGD': 'S\$', 'AED': 'AED', 'MXN': '\$',
    'BRL': 'R\$', 'PHP': '₱', 'VND': '₫', 'MGA': 'Ar', 'CDF': 'FC',
  };

  static String money(num value, [String currency = 'XAF']) {
    final symbol = _symbols[currency] ?? currency;
    return NumberFormat.currency(
      locale: 'fr_FR',
      symbol: symbol,
      decimalDigits: (currency == 'XAF' || currency == 'XOF') ? 0 : 2,
    ).format(value);
  }

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
