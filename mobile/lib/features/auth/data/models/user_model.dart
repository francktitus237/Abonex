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
  );
}
