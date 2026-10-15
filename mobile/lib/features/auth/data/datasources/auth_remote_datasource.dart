import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../models/auth_tokens_model.dart';
import '../models/user_model.dart';

/// Accès réseau pur à l'API d'authentification.
/// Zéro logique métier : on appelle, on parse, on laisse remonter
/// les DioException (le repository les traduit en Failure).
abstract class AuthRemoteDataSource {
  /// POST /auth/login/ → {access, refresh, user}
  Future<({AuthTokensModel tokens, UserModel user})> login({
    required String email,
    required String password,
  });

  /// POST /auth/register/ → {access, refresh, user}
  Future<({AuthTokensModel tokens, UserModel user})> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? country,
  });

  /// GET /auth/me/ → user
  Future<UserModel> me();

  /// PATCH /auth/me/ {first_name?, last_name?, language?} → user
  Future<UserModel> updateMe(Map<String, dynamic> payload);

  /// POST /auth/logout/ {refresh} → blacklist du refresh token.
  Future<void> logout(String refreshToken);

  /// POST /auth/password/forgot/ {email}
  Future<void> forgotPassword(String email);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<({AuthTokensModel tokens, UserModel user})> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
    );
    final data = res.data!;
    return (
      tokens: AuthTokensModel(
        access: data['access'] as String,
        refresh: data['refresh'] as String,
      ),
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<({AuthTokensModel tokens, UserModel user})> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? country,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: {
        'email': email,
        'password': password,
        'first_name': ?firstName,
        'last_name': ?lastName,
        'country': ?country,
      },
    );
    final data = res.data!;
    return (
      tokens: AuthTokensModel(
        access: data['access'] as String,
        refresh: data['refresh'] as String,
      ),
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<UserModel> me() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.me);
    return UserModel.fromJson(res.data!);
  }

  @override
  Future<UserModel> updateMe(Map<String, dynamic> payload) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.me,
      data: payload,
    );
    return UserModel.fromJson(res.data!);
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _dio.post<void>(ApiEndpoints.logout, data: {'refresh': refreshToken});
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _dio.post<void>(ApiEndpoints.forgotPassword, data: {'email': email});
  }
}
