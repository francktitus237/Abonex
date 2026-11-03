import 'package:dio/dio.dart';

import '../l10n/app_strings.dart';
import '../utils/formatters.dart';

/// Exception technique de la couche réseau.
/// Les repositories la convertissent en `Failure` (couche domaine) —
/// les widgets ne voient jamais de DioException.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String message;
  final int? statusCode;

  /// Erreurs de validation DRF, champ par champ.
  final Map<String, String> fieldErrors;

  bool get isNetwork => statusCode == null;

  /// Traduit une DioException en ApiException.
  /// DRF renvoie typiquement soit `{"detail": "..."}`,
  /// soit `{"champ": ["erreur 1", "erreur 2"]}`.
  factory ApiException.fromDio(DioException error) {
    final response = error.response;

    // Pas de réponse = problème réseau pur (timeout, DNS, hors-ligne).
    if (response == null) {
      return ApiException(
        message: AppStrings.t(AppFormatters.lang, 'error.networkLong'),
      );
    }

    final code = response.statusCode;
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return ApiException(message: detail, statusCode: code);
      }

      final fieldErrors = <String, String>{};
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          fieldErrors[entry.key] = value.first.toString();
        } else if (value is String) {
          fieldErrors[entry.key] = value;
        }
      }
      if (fieldErrors.isNotEmpty) {
        // La première erreur de champ est affichée directement —
        // l'utilisateur comprend quoi corriger.
        return ApiException(
          message: fieldErrors.values.first,
          statusCode: code,
          fieldErrors: fieldErrors,
        );
      }
    }

    // Messages clairs par code HTTP — l'utilisateur comprend
    // la situation sans jargon technique.
    return ApiException(
      statusCode: code,
      message: switch (code) {
        400 ||
        401 ||
        403 ||
        404 ||
        409 ||
        422 ||
        429 => AppStrings.t(AppFormatters.lang, 'error.$code'),
        500 || 502 || 503 => AppStrings.t(AppFormatters.lang, 'error.500'),
        null => AppStrings.t(AppFormatters.lang, 'error.unexpected'),
        _ => AppStrings.t(AppFormatters.lang, 'error.other', {'code': '$code'}),
      },
    );
  }
}
