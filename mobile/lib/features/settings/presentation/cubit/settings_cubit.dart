import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/security/biometric_service.dart';
import '../../../../core/storage/settings_storage.dart';
import 'settings_state.dart';

/// Cubit des réglages : lit les préférences au démarrage,
/// les persiste à chaque changement. Singleton get_it —
/// app.dart lit `state.themeMode` / `state.locale` en direct.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({required this._storage, required this._biometric})
    : super(
        SettingsState(
          themeMode: _storage.themeMode,
          locale: _storage.locale,
          biometricEnabled: _storage.biometricEnabled,
        ),
      );

  final SettingsStorage _storage;
  final BiometricService _biometric;

  Future<void> setThemeMode(ThemeMode mode) async {
    // Émission optimiste : l'UI change immédiatement,
    // la persistance suit derrière.
    emit(state.copyWith(themeMode: mode));
    await _storage.setThemeMode(mode);
  }

  Future<void> setLocale(Locale locale) async {
    emit(state.copyWith(locale: locale));
    await _storage.setLocale(locale);
  }

  /// Active/désactive le verrouillage biométrique.
  /// Retourne l'état EFFECTIF : false si le capteur est absent
  /// ou si l'utilisateur a annulé la vérification.
  Future<bool> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      final available = await _biometric.isAvailable();
      if (!available) return false;
      final ok = await _biometric.authenticate(
        reason: 'Confirmez pour activer le déverrouillage biométrique',
      );
      if (!ok) return false;
    }
    emit(state.copyWith(biometricEnabled: enabled));
    await _storage.setBiometricEnabled(enabled);
    return true;
  }
}
