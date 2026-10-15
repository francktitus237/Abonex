import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../auth/data/models/user_model.dart';

/// Accès réseau à la configuration du workspace (pays/devises),
/// aux invitations d'équipe, au catalogue de fournisseurs et
/// aux connecteurs externes. Zéro logique métier ici.
class WorkspaceRemoteDataSource {
  WorkspaceRemoteDataSource(this._dio);

  final Dio _dio;

  /// PATCH /workspace/setup/ → user mis à jour (avec workspace).
  Future<UserModel> setup({
    required String country,
    required String defaultCurrency,
    List<String>? extraCurrencies,
    String? language,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.workspaceSetup,
      data: {
        'country': country,
        'default_currency': defaultCurrency,
        'extra_currencies': ?extraCurrencies,
      },
    );
    return UserModel.fromJson(res.data!);
  }

  /// POST /invites/ {email, role} → invitation créée (avec lien).
  Future<Map<String, dynamic>> invite({
    required String email,
    required String role,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.invites,
      data: {'email': email, 'role': role},
    );
    return res.data!;
  }

  /// GET /providers/catalog/ → [{name, category}] adaptés au pays.
  Future<List<Map<String, dynamic>>> providerCatalog() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.providerCatalog);
    return (res.data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// GET /connectors/ → connecteurs disponibles + champs d'auth.
  Future<List<Map<String, dynamic>>> connectors() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.connectors);
    return (res.data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// POST /connectors/SLUG/sync/ → abonnements détectés.
  Future<List<Map<String, dynamic>>> syncConnector(
    String slug,
    Map<String, String> credentials,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.connectorSync(slug),
      data: {'credentials': credentials},
    );
    return (res.data!['subscriptions'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  /// GET /rates/?base=XAF → taux de change réels.
  /// rates[USD]=0.0016 signifie : 1 XAF = 0.0016 USD.
  Future<Map<String, double>> exchangeRates(String base) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.rates,
      queryParameters: {'base': base},
    );
    return (res.data!['rates'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );
  }

  /// POST /subscriptions/bulk/ → {created, errors}
  Future<Map<String, dynamic>> bulkCreate(
    List<Map<String, dynamic>> items,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.subscriptionsBulk,
      data: {'items': items},
    );
    return res.data!;
  }
}
