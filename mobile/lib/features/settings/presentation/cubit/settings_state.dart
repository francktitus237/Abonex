import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_state.freezed.dart';

/// Réglages utilisateur — persistés dans shared_preferences
/// (le SEUL usage autorisé de shared_preferences par le CDC :
/// thème, langue, onboarding, biométrie).
@freezed
abstract class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default(Locale('fr')) Locale locale,
    @Default(false) bool biometricEnabled,
  }) = _SettingsState;
}
