import 'package:equatable/equatable.dart';

/// Erreur métier remontée jusqu'à la présentation.
/// `sealed` → le `switch` sur les sous-types est exhaustif :
/// si tu ajoutes une Failure, le compilateur t'oblige à la gérer partout.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// Message prêt à être affiché à l'utilisateur (français).
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Pas de réseau / timeout / DNS.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Pas de connexion internet.']);
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
  const AuthFailure([super.message = 'Identifiants incorrects.']);
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
  const CacheFailure([super.message = 'Erreur de cache local.']);
}

/// Tout le reste — ne devrait jamais arriver, mais on ne crash pas.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    super.message = 'Une erreur inattendue est survenue.',
  ]);
}
