import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_endpoints.dart';
import '../models/subscription_model.dart';

/// Accès réseau pur aux abonnements — même règle que l'auth :
/// on appelle, on parse, les DioException remontent au repository.
abstract class SubscriptionRemoteDataSource {
  Future<List<SubscriptionModel>> list();
  Future<SubscriptionModel> create(Map<String, dynamic> payload);
  Future<SubscriptionModel> update(String id, Map<String, dynamic> payload);
  Future<SubscriptionModel> updateStatus(
    String id,
    String status, {
    Map<String, dynamic>? extra,
  });
  Future<void> delete(String id);

  /// GET `attachments/?subscription=<id>` — justificatifs.
  Future<List<Map<String, dynamic>>> attachments(String subscriptionId);

  /// POST /attachments/ multipart — upload reçu/facture.
  Future<Map<String, dynamic>> uploadAttachment({
    required String subscriptionId,
    required String path,
    String? filename,
  });

  Future<void> deleteAttachment(int id);

  /// GET `subscriptions/<id>/comments/` — discussion (étude §G).
  Future<List<Map<String, dynamic>>> comments(String id);

  Future<void> addComment(String id, String text);

  Future<void> deleteComment(int id);
}

class SubscriptionRemoteDataSourceImpl
    implements SubscriptionRemoteDataSource {
  SubscriptionRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  static const _cacheKey = 'cache.subscriptions.v1';

  @override
  Future<List<SubscriptionModel>> list() async {
    try {
      final res = await _dio.get<dynamic>(ApiEndpoints.subscriptions);
      final raw = res.data;
      // DRF paginé {results: [...]} ou liste brute — on gère les deux.
      final items = raw is Map<String, dynamic>
          ? raw['results'] as List<dynamic>
          : raw as List<dynamic>;
      // Cache offline : la dernière réponse réussie est persistée —
      // hors-ligne ou serveur down, l'app reste utilisable en lecture.
      unawaited(
        SharedPreferences.getInstance().then(
          (p) => p.setString(_cacheKey, jsonEncode(items)),
        ),
      );
      return items
          .map((e) => SubscriptionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException {
      final cached = (await SharedPreferences.getInstance())
          .getString(_cacheKey);
      if (cached == null) rethrow;
      return (jsonDecode(cached) as List<dynamic>)
          .map((e) => SubscriptionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  @override
  Future<SubscriptionModel> create(Map<String, dynamic> payload) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.subscriptions,
      data: payload,
    );
    return SubscriptionModel.fromJson(res.data!);
  }

  @override
  Future<SubscriptionModel> update(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.subscription(id),
      data: payload,
    );
    return SubscriptionModel.fromJson(res.data!);
  }

  @override
  Future<SubscriptionModel> updateStatus(
    String id,
    String status, {
    Map<String, dynamic>? extra,
  }) async {    final res = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.subscription(id),
      data: {'status': status, ...?extra},
    );
    return SubscriptionModel.fromJson(res.data!);
  }

  @override
  Future<void> delete(String id) =>
      _dio.delete<void>(ApiEndpoints.subscription(id));

  @override
  Future<List<Map<String, dynamic>>> attachments(
    String subscriptionId,
  ) async {
    final res = await _dio.get<List<dynamic>>(
      'attachments/',
      queryParameters: {'subscription': subscriptionId},
    );
    return (res.data ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> uploadAttachment({
    required String subscriptionId,
    required String path,
    String? filename,
  }) async {
    final form = FormData.fromMap({
      'subscription': subscriptionId,
      'file': await MultipartFile.fromFile(path, filename: filename),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      'attachments/',
      data: form,
    );
    return res.data ?? {};
  }

  @override
  Future<void> deleteAttachment(int id) =>
      _dio.delete<void>('attachments/$id/');

  @override
  Future<List<Map<String, dynamic>>> comments(String id) async {
    final res = await _dio.get<List<dynamic>>(
      'subscriptions/$id/comments/',
    );
    return (res.data ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<void> addComment(String id, String text) =>
      _dio.post<void>(
        'subscriptions/$id/comments/',
        data: {'text': text},
      );

  @override
  Future<void> deleteComment(int id) =>
      _dio.delete<void>('comments/$id/');
}
