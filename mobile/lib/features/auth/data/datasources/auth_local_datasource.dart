import 'dart:convert';

import '../../../../core/storage/token_storage.dart';
import '../models/auth_tokens_model.dart';
import '../models/user_model.dart';

/// Accès au stockage local sécurisé pour la session.
/// Zéro réseau ici.
abstract class AuthLocalDataSource {
  Future<void> saveSession({
    required AuthTokensModel tokens,
    required UserModel user,
  });

  Future<String?> readRefreshToken();

  /// Met à jour le profil en cache sans toucher aux tokens
  /// (utilisé par /auth/me/).
  Future<void> saveUser(UserModel user);

  /// Dernier profil connu — fallback hors-ligne.
  Future<UserModel?> readCachedUser();

  Future<void> clear();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this._storage);

  final TokenStorage _storage;

  @override
  Future<void> saveSession({
    required AuthTokensModel tokens,
    required UserModel user,
  }) async {
    await _storage.saveTokens(access: tokens.access, refresh: tokens.refresh);
    await _storage.saveUserJson(jsonEncode(user.toJson()));
  }

  @override
  Future<String?> readRefreshToken() => _storage.readRefreshToken();

  @override
  Future<void> saveUser(UserModel user) =>
      _storage.saveUserJson(jsonEncode(user.toJson()));

  @override
  Future<UserModel?> readCachedUser() async {
    final json = await _storage.readUserJson();
    if (json == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      // JSON corrompu → on repart propre plutôt que crasher.
      return null;
    }
  }

  @override
  Future<void> clear() => _storage.clear();
}
