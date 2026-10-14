import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_endpoints.dart';

/// Construit le client HTTP unique de l'app.
///
/// - injection automatique du Bearer token sur chaque requête
/// - refresh automatique + retry transparent sur 401
/// - logs réseau en debug uniquement (jamais en release : tokens !)
Dio buildDio({
  required TokenStorage tokenStorage,
  required void Function() onSessionExpired,
}) {
  final baseUrl = Env.apiBaseUrl.endsWith('/')
      ? Env.apiBaseUrl
      : '${Env.apiBaseUrl}/';
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ),
  );

  // Dio séparé SANS intercepteur pour le refresh : sinon un refresh
  // en 401 repasserait par l'intercepteur → boucle infinie.
  final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));

  dio.interceptors.add(
    _AuthInterceptor(dio, refreshDio, tokenStorage, onSessionExpired),
  );

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  return dio;
}

/// QueuedInterceptor : les callbacks sont sérialisés par Dio,
/// ce qui évite les refresh concurrents quand plusieurs requêtes
/// tombent en 401 en même temps.
class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(
    this._dio,
    this._refreshDio,
    this._storage,
    this._onSessionExpired,
  );

  final Dio _dio;
  final Dio _refreshDio;
  final TokenStorage _storage;
  final void Function() _onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final access = await _storage.readAccessToken();
    if (access != null) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // On ne tente un refresh QUE sur 401, jamais sur l'appel de refresh
    // lui-même, ni sur une requête déjà retentée (anti-boucle).
    final isRefreshCall = err.requestOptions.path.endsWith(
      ApiEndpoints.refresh,
    );
    final alreadyRetried = err.requestOptions.extra['retried'] == true;

    if (err.response?.statusCode != 401 || isRefreshCall || alreadyRetried) {
      return handler.next(err);
    }

    final newAccess = await _tryRefresh();
    if (newAccess == null) {
      // Refresh mort → session expirée → le guard du router
      // renverra vers /login.
      _onSessionExpired();
      return handler.next(err);
    }

    // Rejoue la requête d'origine avec le nouveau token.
    final options = err.requestOptions
      ..headers['Authorization'] = 'Bearer $newAccess'
      ..extra['retried'] = true;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Retourne le nouvel access token, ou null si la session est morte.
  Future<String?> _tryRefresh() async {
    final refresh = await _storage.readRefreshToken();
    if (refresh == null) return null;

    try {
      final res = await _refreshDio.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: {'refresh': refresh},
      );
      final data = res.data!;
      await _storage.saveTokens(
        access: data['access'] as String,
        // Rotation SimpleJWT : un nouveau refresh est renvoyé,
        // l'ancien est blacklisté côté serveur.
        refresh: data['refresh'] as String? ?? refresh,
      );
      return data['access'] as String;
    } on DioException {
      await _storage.clear();
      return null;
    }
  }
}
