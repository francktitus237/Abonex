import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage des jetons JWT et de l'utilisateur courant.
///
/// Règle non négociable du cahier des charges : JAMAIS dans
/// shared_preferences — uniquement flutter_secure_storage
/// (Keystore chiffré sur Android, Keychain sur iOS).
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUserJson = 'cached_user';

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccess, value: access),
      _storage.write(key: _kRefresh, value: refresh),
    ]);
  }

  Future<String?> readAccessToken() => _storage.read(key: _kAccess);

  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  /// User courant en JSON — permet de réafficher le profil hors-ligne
  /// sans requête réseau (cache LECTURE seulement, conforme au CDC).
  Future<void> saveUserJson(String json) =>
      _storage.write(key: _kUserJson, value: json);

  Future<String?> readUserJson() => _storage.read(key: _kUserJson);

  /// Déconnexion : on efface tout, sans exception.
  Future<void> clear() => _storage.deleteAll();
}
