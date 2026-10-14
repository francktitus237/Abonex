/// Configuration injectée au build via `--dart-define`.
/// Règle non négociable : AUCUN secret en dur dans le code.
abstract final class Env {
  /// URL de base de l'API Django.
  ///
  /// Défaut : 10.0.2.2 = le localhost de ta machine vu depuis
  /// l'émulateur Android. Pour un téléphone physique ou la prod :
  /// `flutter run --dart-define=API_BASE_URL=https://api.abonex.com/api/v1`
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// DSN Sentry. Vide = Sentry désactivé (dev local).
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');
}
