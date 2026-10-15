import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/user.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Modèle sérialisable — reflète la forme exacte du JSON de l'API.
/// `field_rename: snake` (build.yaml) mappe `first_name` → `firstName`.
@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    required String email,

    /// Le rôle arrive en string ("owner", "manager"…) — parse() applique
    /// le principe de moindre privilège sur une valeur inconnue.
    @JsonKey(fromJson: UserRole.parse) required UserRole role,
    String? firstName,
    String? lastName,
    String? language,
    WorkspaceModel? workspace,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// Data → Domaine. Les couches hautes ne manipulent que des entités.
  User toEntity() => User(
    id: id,
    email: email,
    role: role,
    firstName: firstName,
    lastName: lastName,
    language: language,
    workspace: workspace?.toEntity(),
  );
}

/// Configuration de l'espace de travail (pays, devises) renvoyée
/// par le backend dans le payload utilisateur.
@freezed
abstract class WorkspaceModel with _$WorkspaceModel {
  const WorkspaceModel._();

  const factory WorkspaceModel({
    required String id,
    String? name,
    String? country,
    String? defaultCurrency,
    @Default([]) List<String> extraCurrencies,
    @Default(false) bool configured,
  }) = _WorkspaceModel;

  factory WorkspaceModel.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceModelFromJson(json);

  Workspace toEntity() => Workspace(
    id: id,
    name: name,
    country: country,
    defaultCurrency: defaultCurrency,
    extraCurrencies: extraCurrencies,
    configured: configured,
  );
}
