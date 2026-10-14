import 'package:dio/dio.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

/// Implémentation data du contrat domaine.
/// C'est ICI qu'on convertit les exceptions techniques (Dio/Api)
/// en Failures métier — ni avant (datasource), ni après (cubit).
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this._remote, required this._local});

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) async {
    try {
      final session = await _remote.login(email: email, password: password);
      await _local.saveSession(tokens: session.tokens, user: session.user);
      return Ok(session.user.toEntity());
    } on DioException catch (e) {
      return Err(_toFailure(ApiException.fromDio(e)));
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<User>> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final session = await _remote.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      await _local.saveSession(tokens: session.tokens, user: session.user);
      return Ok(session.user.toEntity());
    } on DioException catch (e) {
      return Err(_toFailure(ApiException.fromDio(e)));
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<User>> currentUser() async {
    try {
      final model = await _remote.me();
      // On met à jour le profil en cache sans toucher aux tokens.
      await _local.saveUser(model);
      return Ok(model.toEntity());
    } on DioException catch (e) {
      // Hors-ligne ou token expiré en cours de refresh :
      // on tente le dernier profil connu avant de déclarer forfait.
      final cached = await _local.readCachedUser();
      if (cached != null) return Ok(cached.toEntity());
      return Err(_toFailure(ApiException.fromDio(e)));
    }
  }

  @override
  Future<bool> hasSession() async => await _local.readRefreshToken() != null;

  @override
  Future<Result<void>> forgotPassword(String email) async {
    try {
      await _remote.forgotPassword(email);
      return const Ok(null);
    } on DioException catch (e) {
      return Err(_toFailure(ApiException.fromDio(e)));
    }
  }

  @override
  Future<void> logout() async {
    // Best effort : si le blacklist serveur échoue (hors-ligne…),
    // on purge quand même le local — la sécurité n'est pas compromise,
    // le token expirera tout seul côté serveur.
    try {
      final refresh = await _local.readRefreshToken();
      if (refresh != null) await _remote.logout(refresh);
    } on DioException {
      // Ignoré volontairement.
    } finally {
      await _local.clear();
    }
  }

  Failure _toFailure(ApiException e) => switch (e.statusCode) {
    400 => ValidationFailure(e.message, fieldErrors: e.fieldErrors),
    401 || 403 => AuthFailure(e.message),
    null => const NetworkFailure(),
    _ => ServerFailure(e.message, statusCode: e.statusCode),
  };
}
