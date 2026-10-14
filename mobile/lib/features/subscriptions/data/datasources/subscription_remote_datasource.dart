import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../models/subscription_model.dart';

/// Accès réseau pur aux abonnements — même règle que l'auth :
/// on appelle, on parse, les DioException remontent au repository.
abstract class SubscriptionRemoteDataSource {
  Future<List<SubscriptionModel>> list();
  Future<SubscriptionModel> create(Map<String, dynamic> payload);
  Future<SubscriptionModel> updateStatus(String id, String status);
  Future<void> delete(String id);
}

class SubscriptionRemoteDataSourceImpl
    implements SubscriptionRemoteDataSource {
  SubscriptionRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<SubscriptionModel>> list() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.subscriptions);
    final raw = res.data;
    // DRF paginé {results: [...]} ou liste brute — on gère les deux.
    final items = raw is Map<String, dynamic>
        ? raw['results'] as List<dynamic>
        : raw as List<dynamic>;
    return items
        .map((e) => SubscriptionModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
  Future<SubscriptionModel> updateStatus(String id, String status) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.subscription(id),
      data: {'status': status},
    );
    return SubscriptionModel.fromJson(res.data!);
  }

  @override
  Future<void> delete(String id) =>
      _dio.delete<void>(ApiEndpoints.subscription(id));
}
