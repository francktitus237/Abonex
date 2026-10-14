import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglages utilisateur NON sensibles — c'est le SEUL usage autorisé
/// de shared_preferences par le cahier des charges :
/// thème, langue, onboarding vu, biométrie activée.
/// Jamais de token ni de donnée financière ici.
class SettingsStorage {
  SettingsStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _kThemeMode = 'theme_mode';
  static const _kLocale = 'locale';
  static const _kOnboardingSeen = 'onboarding_seen';
  static const _kFirstLoginGuideSeen = 'first_login_guide_seen';
  static const _kBiometricEnabled = 'biometric_enabled';
  static const _kMonthlyBudget = 'monthly_budget';

  // Clair par défaut : identité de marque Abonex. L'utilisateur
  // peut passer en sombre ou suivre le système depuis le profil.
  ThemeMode get themeMode => switch (_prefs.getString(_kThemeMode)) {
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => ThemeMode.light,
  };

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);

  /// FR par défaut, EN ensuite (CDC).
  Locale get locale => Locale(_prefs.getString(_kLocale) ?? 'fr');

  Future<void> setLocale(Locale locale) =>
      _prefs.setString(_kLocale, locale.languageCode);

  bool get onboardingSeen => _prefs.getBool(_kOnboardingSeen) ?? false;

  Future<void> setOnboardingSeen() => _prefs.setBool(_kOnboardingSeen, true);

  bool get firstLoginGuideSeen =>
      _prefs.getBool(_kFirstLoginGuideSeen) ?? false;

  Future<void> setFirstLoginGuideSeen() =>
      _prefs.setBool(_kFirstLoginGuideSeen, true);

  bool get biometricEnabled => _prefs.getBool(_kBiometricEnabled) ?? false;

  Future<void> setBiometricEnabled(bool enabled) =>
      _prefs.setBool(_kBiometricEnabled, enabled);

  static const _kSoundAlerts = 'sound_alerts';

  /// Budget mensuel saisi par l'utilisateur (FCFA).
  /// 0 = non défini → le dashboard propose de le configurer.
  double get monthlyBudget => _prefs.getDouble(_kMonthlyBudget) ?? 0;

  Future<void> setMonthlyBudget(double value) =>
      _prefs.setDouble(_kMonthlyBudget, value);

  static const _kReminderDays = 'reminder_days';
  static const _kReminderHour = 'reminder_hour';

  /// Rappels sonores type alarme : plein écran + sonnerie forte
  /// pour ne jamais rater une échéance. Activé par défaut.
  bool get soundAlerts => _prefs.getBool(_kSoundAlerts) ?? true;

  Future<void> setSoundAlerts(bool enabled) =>
      _prefs.setBool(_kSoundAlerts, enabled);

  /// Nombre de jours AVANT l'échéance pour chaque rappel.
  /// 0 = le jour même. Défaut : J-7, J-3 et J.
  List<int> get reminderDays {
    final raw = _prefs.getString(_kReminderDays) ?? '7,3,0';
    return raw
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .where((d) => d >= 0 && d <= 30)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  Future<void> setReminderDays(List<int> days) =>
      _prefs.setString(_kReminderDays, (days.toSet().toList()..sort()).join(','));

  /// Heure du rappel (0-23). Défaut : 9h.
  int get reminderHour => _prefs.getInt(_kReminderHour) ?? 9;

  Future<void> setReminderHour(int hour) =>
      _prefs.setInt(_kReminderHour, hour.clamp(0, 23));
}
