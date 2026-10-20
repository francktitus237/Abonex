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

  /// POST /subscriptions/bulk/ — import en masse.
  static const subscriptionsBulk = 'subscriptions/bulk/';

  /// Configuration de premier démarrage : pays, devises, langue.
  static const workspaceSetup = 'workspace/setup/';

  /// Invitations d'équipe + acceptation par token.
  static const invites = 'invites/';
  static const inviteAccept = 'invites/accept/';

  /// Catalogue de fournisseurs suggérés (filtré par pays serveur-side).
  static const providerCatalog = 'providers/catalog/';

  /// GET /rates/?base=XXX — taux de change réels.
  static const rates = 'rates/';

  /// Connecteurs externes : GET /connectors/ + POST /connectors/x/sync/.
  static const connectors = 'connectors/';
  static String connectorSync(String slug) => 'connectors/$slug/sync/';

  /// GET /meta/app-version/ → dernière version publiée + lien
  /// de téléchargement (mise à jour de l'app depuis le profil).
  static const appVersion = 'meta/app-version/';

  /// Agrégation bancaire (Powens) : login OAuth + échange du code.
  static const powensLogin = 'connectors/powens/login/';
  static const powensCallback = 'connectors/powens/callback/';

  /// Comptes externes connectés : GET /connections/ +
  /// POST/DELETE /connections/ID/resync/.
  static const connections = 'connections/';
  static String connectionResync(int id) => 'connections/$id/resync/';
}
