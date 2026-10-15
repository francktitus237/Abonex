import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';

/// Rôles métier du cahier des charges.
/// Le `name` correspond au slug renvoyé par l'API Django.
enum UserRole {
  /// Propriétaire (Super Admin) : tous les droits.
  owner,

  /// Gestionnaire/Comptable : CRUD services/factures + paiements,
  /// mais PAS de gestion des rôles ni de suppression définitive.
  manager,

  /// Assistant : consulte les échéances, déclare des paiements
  /// (soumis à validation du propriétaire).
  assistant,

  /// Lecteur : lecture seule.
  viewer;

  /// Rôle inconnu renvoyé par l'API → on retombe sur le MOINS
  /// privilégié (principe de moindre privilège, jamais l'inverse).
  static UserRole parse(String value) => UserRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => UserRole.viewer,
  );
}

/// Permissions vues côté UI.
/// ATTENTION : Flutter ne fait que MASQUER l'interface.
/// La sécurité réelle est toujours vérifiée côté Django (CDC).
extension UserRoleX on UserRole {
  String get label => switch (this) {
    UserRole.owner => 'Propriétaire',
    UserRole.manager => 'Gestionnaire',
    UserRole.assistant => 'Assistant',
    UserRole.viewer => 'Lecteur',
  };

  bool get canManageUsers => this == UserRole.owner;

  bool get canEditFinancials =>
      this == UserRole.owner || this == UserRole.manager;

  bool get canDeclarePayment => this != UserRole.viewer;

  bool get isReadOnly => this == UserRole.viewer;
}

/// Espace de travail — configuration pays/devises du compte.
@freezed
abstract class Workspace with _$Workspace {
  const Workspace._();

  const factory Workspace({
    required String id,
    String? name,
    String? country,
    String? defaultCurrency,
    @Default([]) List<String> extraCurrencies,
    @Default(false) bool configured,
  }) = _Workspace;
}

/// Utilisateur authentifié — entité du domaine, indépendante du JSON.
@freezed
abstract class User with _$User {
  const User._();

  const factory User({
    required String id,
    required String email,
    required UserRole role,
    String? firstName,
    String? lastName,
    String? language,
    Workspace? workspace,
  }) = _User;

  String get fullName => [
    firstName,
    lastName,
  ].where((part) => part != null && part.isNotEmpty).join(' ');
}
