// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserModel {

 String get id; String get email;/// Le rôle arrive en string ("owner", "manager"…) — parse() applique
/// le principe de moindre privilège sur une valeur inconnue.
@JsonKey(fromJson: UserRole.parse) UserRole get role; String? get firstName; String? get lastName; String? get language; WorkspaceModel? get workspace;
/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserModelCopyWith<UserModel> get copyWith => _$UserModelCopyWithImpl<UserModel>(this as UserModel, _$identity);

  /// Serializes this UserModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserModel&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.role, role) || other.role == role)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.language, language) || other.language == language)&&(identical(other.workspace, workspace) || other.workspace == workspace));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,email,role,firstName,lastName,language,workspace);

@override
String toString() {
  return 'UserModel(id: $id, email: $email, role: $role, firstName: $firstName, lastName: $lastName, language: $language, workspace: $workspace)';
}


}

/// @nodoc
abstract mixin class $UserModelCopyWith<$Res>  {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) _then) = _$UserModelCopyWithImpl;
@useResult
$Res call({
 String id, String email,@JsonKey(fromJson: UserRole.parse) UserRole role, String? firstName, String? lastName, String? language, WorkspaceModel? workspace
});


$WorkspaceModelCopyWith<$Res>? get workspace;

}
/// @nodoc
class _$UserModelCopyWithImpl<$Res>
    implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._self, this._then);

  final UserModel _self;
  final $Res Function(UserModel) _then;

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? email = null,Object? role = null,Object? firstName = freezed,Object? lastName = freezed,Object? language = freezed,Object? workspace = freezed,}) {
  return _then(UserModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,workspace: freezed == workspace ? _self.workspace : workspace // ignore: cast_nullable_to_non_nullable
as WorkspaceModel?,
  ));
}
/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkspaceModelCopyWith<$Res>? get workspace {
    if (_self.workspace == null) {
    return null;
  }

  return $WorkspaceModelCopyWith<$Res>(_self.workspace!, (value) {
    return _then(_self.copyWith(workspace: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserModel].
extension UserModelPatterns on UserModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserModel value)  $default,){
final _that = this;
switch (_that) {
case _UserModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserModel value)?  $default,){
final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String email, @JsonKey(fromJson: UserRole.parse)  UserRole role,  String? firstName,  String? lastName,  String? language,  WorkspaceModel? workspace)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that.id,_that.email,_that.role,_that.firstName,_that.lastName,_that.language,_that.workspace);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String email, @JsonKey(fromJson: UserRole.parse)  UserRole role,  String? firstName,  String? lastName,  String? language,  WorkspaceModel? workspace)  $default,) {final _that = this;
switch (_that) {
case _UserModel():
return $default(_that.id,_that.email,_that.role,_that.firstName,_that.lastName,_that.language,_that.workspace);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String email, @JsonKey(fromJson: UserRole.parse)  UserRole role,  String? firstName,  String? lastName,  String? language,  WorkspaceModel? workspace)?  $default,) {final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that.id,_that.email,_that.role,_that.firstName,_that.lastName,_that.language,_that.workspace);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserModel extends UserModel {
  const _UserModel({required this.id, required this.email, @JsonKey(fromJson: UserRole.parse) required this.role, this.firstName, this.lastName, this.language, this.workspace}): super._();
  factory _UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);

@override final  String id;
@override final  String email;
/// Le rôle arrive en string ("owner", "manager"…) — parse() applique
/// le principe de moindre privilège sur une valeur inconnue.
@override@JsonKey(fromJson: UserRole.parse) final  UserRole role;
@override final  String? firstName;
@override final  String? lastName;
@override final  String? language;
@override final  WorkspaceModel? workspace;

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserModelCopyWith<_UserModel> get copyWith => __$UserModelCopyWithImpl<_UserModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserModel&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.role, role) || other.role == role)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.language, language) || other.language == language)&&(identical(other.workspace, workspace) || other.workspace == workspace));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,email,role,firstName,lastName,language,workspace);

@override
String toString() {
  return 'UserModel(id: $id, email: $email, role: $role, firstName: $firstName, lastName: $lastName, language: $language, workspace: $workspace)';
}


}

/// @nodoc
abstract mixin class _$UserModelCopyWith<$Res> implements $UserModelCopyWith<$Res> {
  factory _$UserModelCopyWith(_UserModel value, $Res Function(_UserModel) _then) = __$UserModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String email,@JsonKey(fromJson: UserRole.parse) UserRole role, String? firstName, String? lastName, String? language, WorkspaceModel? workspace
});


@override $WorkspaceModelCopyWith<$Res>? get workspace;

}
/// @nodoc
class __$UserModelCopyWithImpl<$Res>
    implements _$UserModelCopyWith<$Res> {
  __$UserModelCopyWithImpl(this._self, this._then);

  final _UserModel _self;
  final $Res Function(_UserModel) _then;

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = null,Object? role = null,Object? firstName = freezed,Object? lastName = freezed,Object? language = freezed,Object? workspace = freezed,}) {
  return _then(_UserModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,workspace: freezed == workspace ? _self.workspace : workspace // ignore: cast_nullable_to_non_nullable
as WorkspaceModel?,
  ));
}

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkspaceModelCopyWith<$Res>? get workspace {
    if (_self.workspace == null) {
    return null;
  }

  return $WorkspaceModelCopyWith<$Res>(_self.workspace!, (value) {
    return _then(_self.copyWith(workspace: value));
  });
}
}


/// @nodoc
mixin _$WorkspaceModel {

 String get id; String? get name; String? get country; String? get defaultCurrency; List<String> get extraCurrencies; bool get configured;
/// Create a copy of WorkspaceModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceModelCopyWith<WorkspaceModel> get copyWith => _$WorkspaceModelCopyWithImpl<WorkspaceModel>(this as WorkspaceModel, _$identity);

  /// Serializes this WorkspaceModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.country, country) || other.country == country)&&(identical(other.defaultCurrency, defaultCurrency) || other.defaultCurrency == defaultCurrency)&&const DeepCollectionEquality().equals(other.extraCurrencies, extraCurrencies)&&(identical(other.configured, configured) || other.configured == configured));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,country,defaultCurrency,const DeepCollectionEquality().hash(extraCurrencies),configured);

@override
String toString() {
  return 'WorkspaceModel(id: $id, name: $name, country: $country, defaultCurrency: $defaultCurrency, extraCurrencies: $extraCurrencies, configured: $configured)';
}


}

/// @nodoc
abstract mixin class $WorkspaceModelCopyWith<$Res>  {
  factory $WorkspaceModelCopyWith(WorkspaceModel value, $Res Function(WorkspaceModel) _then) = _$WorkspaceModelCopyWithImpl;
@useResult
$Res call({
 String id, String? name, String? country, String? defaultCurrency, List<String> extraCurrencies, bool configured
});




}
/// @nodoc
class _$WorkspaceModelCopyWithImpl<$Res>
    implements $WorkspaceModelCopyWith<$Res> {
  _$WorkspaceModelCopyWithImpl(this._self, this._then);

  final WorkspaceModel _self;
  final $Res Function(WorkspaceModel) _then;

/// Create a copy of WorkspaceModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = freezed,Object? country = freezed,Object? defaultCurrency = freezed,Object? extraCurrencies = null,Object? configured = null,}) {
  return _then(WorkspaceModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,defaultCurrency: freezed == defaultCurrency ? _self.defaultCurrency : defaultCurrency // ignore: cast_nullable_to_non_nullable
as String?,extraCurrencies: null == extraCurrencies ? _self.extraCurrencies : extraCurrencies // ignore: cast_nullable_to_non_nullable
as List<String>,configured: null == configured ? _self.configured : configured // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceModel].
extension WorkspaceModelPatterns on WorkspaceModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceModel value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceModel value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? name,  String? country,  String? defaultCurrency,  List<String> extraCurrencies,  bool configured)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceModel() when $default != null:
return $default(_that.id,_that.name,_that.country,_that.defaultCurrency,_that.extraCurrencies,_that.configured);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? name,  String? country,  String? defaultCurrency,  List<String> extraCurrencies,  bool configured)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceModel():
return $default(_that.id,_that.name,_that.country,_that.defaultCurrency,_that.extraCurrencies,_that.configured);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? name,  String? country,  String? defaultCurrency,  List<String> extraCurrencies,  bool configured)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceModel() when $default != null:
return $default(_that.id,_that.name,_that.country,_that.defaultCurrency,_that.extraCurrencies,_that.configured);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkspaceModel extends WorkspaceModel {
  const _WorkspaceModel({required this.id, this.name, this.country, this.defaultCurrency,  List<String> extraCurrencies = const [], this.configured = false}): _extraCurrencies = extraCurrencies,super._();
  factory _WorkspaceModel.fromJson(Map<String, dynamic> json) => _$WorkspaceModelFromJson(json);

@override final  String id;
@override final  String? name;
@override final  String? country;
@override final  String? defaultCurrency;
 final  List<String> _extraCurrencies;
@override@JsonKey() List<String> get extraCurrencies {
  if (_extraCurrencies is EqualUnmodifiableListView) return _extraCurrencies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_extraCurrencies);
}

@override@JsonKey() final  bool configured;

/// Create a copy of WorkspaceModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceModelCopyWith<_WorkspaceModel> get copyWith => __$WorkspaceModelCopyWithImpl<_WorkspaceModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkspaceModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.country, country) || other.country == country)&&(identical(other.defaultCurrency, defaultCurrency) || other.defaultCurrency == defaultCurrency)&&const DeepCollectionEquality().equals(other._extraCurrencies, _extraCurrencies)&&(identical(other.configured, configured) || other.configured == configured));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,country,defaultCurrency,const DeepCollectionEquality().hash(_extraCurrencies),configured);

@override
String toString() {
  return 'WorkspaceModel(id: $id, name: $name, country: $country, defaultCurrency: $defaultCurrency, extraCurrencies: $extraCurrencies, configured: $configured)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceModelCopyWith<$Res> implements $WorkspaceModelCopyWith<$Res> {
  factory _$WorkspaceModelCopyWith(_WorkspaceModel value, $Res Function(_WorkspaceModel) _then) = __$WorkspaceModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String? name, String? country, String? defaultCurrency, List<String> extraCurrencies, bool configured
});




}
/// @nodoc
class __$WorkspaceModelCopyWithImpl<$Res>
    implements _$WorkspaceModelCopyWith<$Res> {
  __$WorkspaceModelCopyWithImpl(this._self, this._then);

  final _WorkspaceModel _self;
  final $Res Function(_WorkspaceModel) _then;

/// Create a copy of WorkspaceModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = freezed,Object? country = freezed,Object? defaultCurrency = freezed,Object? extraCurrencies = null,Object? configured = null,}) {
  return _then(_WorkspaceModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,defaultCurrency: freezed == defaultCurrency ? _self.defaultCurrency : defaultCurrency // ignore: cast_nullable_to_non_nullable
as String?,extraCurrencies: null == extraCurrencies ? _self._extraCurrencies : extraCurrencies // ignore: cast_nullable_to_non_nullable
as List<String>,configured: null == configured ? _self.configured : configured // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
