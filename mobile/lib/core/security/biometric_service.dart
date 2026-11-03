import 'package:local_auth/local_auth.dart';

import '../l10n/app_strings.dart';
import '../utils/formatters.dart';

/// Verrouillage biométrique (empreinte / Face ID) + fallback code PIN.
///
/// Nécessite côté Android : MainActivity en FlutterFragmentActivity
/// et la permission USE_BIOMETRIC (déjà configurés).
class BiometricService {
  BiometricService([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// L'appareil a-t-il du hardware biométrique OU un verrouillage écran ?
  Future<bool> isAvailable() async =>
      await _auth.canCheckBiometrics || await _auth.isDeviceSupported();

  /// Demande une authentification biométrique (PIN/schéma en fallback).
  /// Retourne false si annulé, échoué ou indisponible.
  Future<bool> authenticate({String? reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason:
            reason ??
            AppStrings.t(AppFormatters.lang, 'settings.biometricReason'),
        // Si l'app passe en arrière-plan pendant la demande,
        // la biométrie retente automatiquement au retour au premier plan.
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // Matériel absent, aucune biométrie enrôlée, etc.
      return false;
    }
  }
}
