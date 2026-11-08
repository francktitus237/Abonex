import 'package:equatable/equatable.dart';

import '../l10n/app_strings.dart';
import '../utils/formatters.dart';

/// Erreur métier remontée jusqu'à la présentation.
/// `sealed` → le `switch` sur les sous-types est exhaustif :
/// si tu ajoutes une Failure, le compilateur t'oblige à la gérer partout.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// Message renvoyé par le serveur ou la couche réseau.
  /// Vide → le message traduit par défaut est utilisé.
  final String message;

  /// Message prêt à être affiché, dans la langue courante.
  /// Les sous-classes avec un message par défaut le traduisent via
  /// AppStrings ; un message serveur est renvoyé tel quel.
  String get localizedMessage => message;

  String _orDefault(String key) =>
      message.isEmpty ? AppStrings.t(AppFormatters.lang, key) : message;

  @override
  List<Object?> get props => [message];
}

/// Pas de réseau / timeout / DNS.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = '']);

  @override
  String get localizedMessage => _orDefault('error.network');
}

/// Erreur serveur (4xx/5xx hors auth et validation).
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

/// 401/403 : identifiants invalides ou droits insuffisants.
final class AuthFailure extends Failure {
  const AuthFailure([super.message = '']);

  @override
  String get localizedMessage => _orDefault('error.auth');
}

/// 400 : erreurs de validation renvoyées par DRF, champ par champ.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}});

  /// ex. `{'email': 'Ce champ est obligatoire.'}`
  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [message, fieldErrors];
}

/// Lecture/écriture du cache local (drift) impossible.
final class CacheFailure extends Failure {
  const CacheFailure([super.message = '']);

  @override
  String get localizedMessage => _orDefault('error.cache');
}

/// Tout le reste — ne devrait jamais arriver, mais on ne crash pas.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = '']);

  @override
  String get localizedMessage => _orDefault('error.unexpected');
}

/// 2FA requise — le login attend le code TOTP ; `preToken`
/// doit être renvoyé à /auth/2fa/verify/ (étude Phase 4).
final class TwoFaRequired extends Failure {
  const TwoFaRequired(this.preToken, [super.message = '']);

  final String preToken;

  @override
  String get localizedMessage => 'Code de vérification requis';
}
