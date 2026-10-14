/// Contrat d'API avec le backend Django — API versionnée `/api/v1/`.
///
/// CONTRAT À FAIRE RESPECTER CÔTÉ DJANGO (Sprint 0 backend) :
/// - POST   /auth/login/            {email, password} → {access, refresh, user}
/// - POST   /auth/token/refresh/    {refresh}         → {access, refresh} (rotation)
/// - POST   /auth/logout/           {refresh}         → 204 (blacklist)
/// - GET    /auth/me/                                → user
/// - POST   /auth/password/forgot/  {email}          → 204
/// - POST   /auth/password/reset/   {uid, token, new_password} → 204
///
/// Jamais de chaîne d'URL en dur ailleurs dans le code.
abstract final class ApiEndpoints {
  static const login = 'auth/login/';
  static const register = 'auth/register/';
  static const refresh = 'auth/token/refresh/';
  static const logout = 'auth/logout/';
  static const me = 'auth/me/';
  static const forgotPassword = 'auth/password/forgot/';
  static const resetPassword = 'auth/password/reset/';

  static const users = 'users/';
  static String user(String id) => 'users/$id/';

  /// GET /subscriptions/ · POST /subscriptions/ (liste + création).
  /// DRF paginé {results: [...]} ou liste brute — les deux sont gérés.
  static const subscriptions = 'subscriptions/';

  /// PATCH /subscriptions/ID/ — ex. {status: 'paid'}.
  static String subscription(String id) => 'subscriptions/$id/';
  static String subscriptionHistory(String id) => 'subscriptions/$id/history/';
}
