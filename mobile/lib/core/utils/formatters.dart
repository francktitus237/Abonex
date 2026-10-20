import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';

/// Formatage unique de l'app — montants en FCFA, dates FR/EN.
/// Hand-roll pour les dates : pas de `initializeDateFormatting` requis.
abstract final class AppFormatters {
  /// Langue courante ('fr' | 'en'). Mise à jour par SettingsCubit
  /// au démarrage et à chaque changement de langue.
  static String lang = 'fr';

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

  static const _monthsFr = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];
  static const _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _monthsLongFr = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  static const _monthsLongEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _weekdaysFr = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
  ];
  static const _weekdaysEn = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];

  static bool get _en => lang == 'en';

  /// FR `12 mars` · EN `Mar 12`
  static String dateShort(DateTime d) => _en
      ? '${_monthsEn[d.month - 1]} ${d.day}'
      : '${d.day} ${_monthsFr[d.month - 1]}';

  /// FR `lundi 12 mars` · EN `Monday, Mar 12`
  static String dateLong(DateTime d) => _en
      ? '${_weekdaysEn[d.weekday - 1]}, ${_monthsEn[d.month - 1]} ${d.day}'
      : '${_weekdaysFr[d.weekday - 1]} ${d.day} ${_monthsFr[d.month - 1]}';

  /// FR `mars 2026` · EN `March 2026`
  static String monthYear(DateTime d) => _en
      ? '${_monthsLongEn[d.month - 1]} ${d.year}'
      : '${_monthsLongFr[d.month - 1]} ${d.year}';

  /// "Dans 3 j" / "Aujourd'hui" / "En retard de 2 j" (ou équivalent EN)
  static String relativeDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    return switch (diff) {
      0 => AppStrings.t(lang, 'date.today'),
      1 => AppStrings.t(lang, 'date.tomorrow'),
      < 0 => AppStrings.t(lang, 'date.late', {'n': '${-diff}'}),
      _ => AppStrings.t(lang, 'date.in', {'n': '$diff'}),
    };
  }
}