import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../auth/data/models/user_model.dart';

/// Accès réseau à la configuration du workspace (pays/devises),
/// aux invitations d'équipe, au catalogue de fournisseurs et
/// aux connecteurs externes. Zéro logique métier ici.
class WorkspaceRemoteDataSource {
  WorkspaceRemoteDataSource(this._dio);

  final Dio _dio;

  Future<double> monthlyBudget() async {
    final response = await _dio.get<Map<String, dynamic>>('workspace/budget/');
    return double.tryParse(response.data?['monthly_budget']?.toString() ?? '') ?? 0;
  }

  Future<void> updateMonthlyBudget(double amount) async {
    await _dio.patch<void>('workspace/budget/', data: {'monthly_budget': amount});
  }

  /// GET /payments/ — déclarations en attente (owner/manager).
  Future<List<Map<String, dynamic>>> pendingPayments() async {
    final res = await _dio.get<List<dynamic>>('payments/');
    return (res.data ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// GET/POST/DELETE /departments/ — centres de coûts (étude §B).
  Future<List<Map<String, dynamic>>> departments() async {
    final res = await _dio.get<List<dynamic>>('departments/');
    return (res.data ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> createDepartment(String name) =>
      _dio.post<void>('departments/', data: {'name': name});

  Future<void> updateDepartment(int id, String name) => _dio.patch<void>(
    'departments/$id/',
    data: {'name': name},
  );

  Future<void> deleteDepartment(int id) =>
      _dio.delete<void>('departments/$id/');

  /// GET/POST/DELETE /budgets/ — budgets par catégorie ou
  /// département (étude §B).
  Future<List<Map<String, dynamic>>> budgets() async {
    final res = await _dio.get<List<dynamic>>('budgets/');
    return (res.data ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> createBudget(
    Map<String, dynamic> data,
  ) => _dio.post<void>('budgets/', data: data);

  Future<void> deleteBudget(int id) =>
      _dio.delete<void>('budgets/$id/');

  /// GET `export/<format>/` — export comptable : xlsx | pdf.
  /// Renvoie les octets du fichier (auth requise → pas de
  /// simple ouverture d'URL).
  Future<List<int>> exportBytes(String format) async {
    final res = await _dio.get<List<int>>(
      'export/$format/',
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data ?? const [];
  }

  /// GET /treasury/?days=90&start_balance=X — prévision de
  /// trésorerie (étude §C).
  Future<Map<String, dynamic>> treasury({
    int days = 90,
    double startBalance = 0,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      'treasury/',
      queryParameters: {
        'days': days,
        'start_balance': startBalance,
      },
    );
    return res.data ?? {};
  }

  /// GET /memberships/ — espaces accessibles (multi-espaces §4.2).
  Future<List<Map<String, dynamic>>> memberships() async {
    final res = await _dio.get<List<dynamic>>('memberships/');
    return (res.data ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// POST `memberships/<id>/activate/` — bascule l'espace actif.
  Future<void> activateMembership(int id) =>
      _dio.post<void>('memberships/$id/activate/');

  /// GET /audit/ — journal d'audit de l'espace (propriétaire).
  Future<List<Map<String, dynamic>>> auditLog() async {
    final res = await _dio.get<List<dynamic>>('audit/');
    return (res.data ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// POST `payments/<id>/verdict/` — valide ou refuse une
  /// déclaration d'assistant (motif optionnel au refus).
  Future<void> paymentVerdict(
    int id,
    String verdict, {
    String? reason,
  }) => _dio.post<void>(
    'payments/$id/verdict/',
    data: {'verdict': verdict, 'reason': ?reason},
  );

  /// GET /insights/ — recommandations intelligentes : doublons,
  /// alternatives moins chères, reste à vivre, total mensuel.
  Future<Map<String, dynamic>> insights() async {
    final res = await _dio.get<Map<String, dynamic>>('insights/');
    return res.data ?? <String, dynamic>{};
  }

  // ---------- Employés (espaces entreprise) ----------

  /// GET /employees/ → employés de l'espace courant.
  Future<List<Map<String, dynamic>>> employees() async {
    final res = await _dio.get<dynamic>('employees/');
    final raw = res.data;
    final items = raw is Map<String, dynamic>
        ? raw['results'] as List<dynamic>
        : raw as List<dynamic>;
    return items.cast<Map<String, dynamic>>();
  }

  /// POST /employees/ — crée l'employé + sa paie payroll.
  Future<Map<String, dynamic>> createEmployee(
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      'employees/',
      data: payload,
    );
    return res.data!;
  }

  /// PATCH /employees/ID/ — met à jour + resynchronise la paie.
  Future<Map<String, dynamic>> updateEmployee(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      'employees/$id/',
      data: payload,
    );
    return res.data!;
  }

  /// DELETE /employees/ID/ — supprime l'employé et son
  /// échéance payroll associée.
  Future<void> deleteEmployee(String id) async {
    await _dio.delete<void>('employees/$id/');
  }

  /// GET /export/csv/ → télécharge le CSV des données de
  /// l'espace dans [savePath] (export RGPD / compta).
  Future<String> exportCsv(String savePath) async {
    await _dio.download(ApiEndpoints.exportCsv, savePath);
    return savePath;
  }

  /// DELETE /auth/me/ {password} — suppression définitive
  /// du compte (le mot de passe confirme l'action côté API).
  Future<void> deleteAccount(String password) async {
    await _dio.delete<void>(
      ApiEndpoints.me,
      data: {'password': password},
    );
  }

  /// POST /report/monthly/send/ — rapport mensuel PDF par
  /// e-mail au propriétaire (étude §F).
  Future<Map<String, dynamic>> sendMonthlyReport() async {
    final res = await _dio.post<Map<String, dynamic>>(
      'report/monthly/send/',
    );
    return res.data ?? {};
  }

  /// GET /users/ — membres de l'espace (propriétaire) : liste
  /// pour l'assignation d'échéances (étude §B).
  Future<List<Map<String, dynamic>>> members() async {
    final res = await _dio.get<List<dynamic>>('users/');
    return (res.data ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// GET /workspace/budget/ — réglages de l'espace (inclut
  /// approval_threshold, budget mensuel, infos société).
  Future<Map<String, dynamic>> workspaceInfo() async {
    final res = await _dio.get<Map<String, dynamic>>(
      'workspace/budget/',
    );
    return res.data ?? {};
  }

  /// PATCH /workspace/setup/ — infos société (nom affiché,
  /// raison sociale, NIU, secteur, taille). Réservé
  /// owner/manager côté serveur.
  Future<void> updateCompany(Map<String, String> data) =>
      _dio.patch<void>(ApiEndpoints.workspaceSetup, data: data);

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

  /// GET /meta/app-version/ → {latest_version, update_url}.
  Future<Map<String, dynamic>> appVersion() async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.appVersion,
    );
    return res.data!;
  }

  /// GET /connectors/powens/login/ → (URL du webview, state anti-CSRF).
  /// Le `state` est renvoyé par Powens dans le callback et doit
  /// être retransmis au serveur pour prouver la liaison de session.
  Future<(String, String)> powensLogin() async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.powensLogin,
    );
    return (
      res.data!['auth_url'] as String,
      res.data!['state'] as String? ?? '',
    );
  }

  /// POST /connectors/powens/callback/ {code, state} → abonnements
  /// détectés à partir des prélèvements récurrents du relevé.
  Future<List<Map<String, dynamic>>> powensCallback(
    String code,
    String state,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.powensCallback,
      data: {'code': code, 'state': state},
    );
    return (res.data!['subscriptions'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  /// GET /connections/ → comptes externes déjà connectés.
  Future<List<Map<String, dynamic>>> connections() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.connections);
    return (res.data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// POST /connections/ID/resync/ → re-synchronise sans ressaisir
  /// les identifiants (stockés chiffrés côté serveur).
  Future<List<Map<String, dynamic>>> resyncConnection(int id) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.connectionResync(id),
    );
    return (res.data!['subscriptions'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  /// DELETE /connections/ID/resync/ → déconnecte le compte.
  Future<void> disconnectConnection(int id) async {
    await _dio.delete<void>(ApiEndpoints.connectionResync(id));
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
