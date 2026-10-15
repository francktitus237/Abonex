// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserModel _$UserModelFromJson(Map<String, dynamic> json) => _UserModel(
  id: json['id'] as String,
  email: json['email'] as String,
  role: UserRole.parse(json['role'] as String),
  firstName: json['first_name'] as String?,
  lastName: json['last_name'] as String?,
  language: json['language'] as String?,
  workspace: json['workspace'] == null
      ? null
      : WorkspaceModel.fromJson(json['workspace'] as Map<String, dynamic>),
);

Map<String, dynamic> _$UserModelToJson(_UserModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'role': _$UserRoleEnumMap[instance.role]!,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'language': instance.language,
      'workspace': instance.workspace,
    };

const _$UserRoleEnumMap = {
  UserRole.owner: 'owner',
  UserRole.manager: 'manager',
  UserRole.assistant: 'assistant',
  UserRole.viewer: 'viewer',
};

_WorkspaceModel _$WorkspaceModelFromJson(Map<String, dynamic> json) =>
    _WorkspaceModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      country: json['country'] as String?,
      defaultCurrency: json['default_currency'] as String?,
      extraCurrencies:
          (json['extra_currencies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      configured: json['configured'] as bool? ?? false,
    );

Map<String, dynamic> _$WorkspaceModelToJson(_WorkspaceModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'country': instance.country,
      'default_currency': instance.defaultCurrency,
      'extra_currencies': instance.extraCurrencies,
      'configured': instance.configured,
    };
