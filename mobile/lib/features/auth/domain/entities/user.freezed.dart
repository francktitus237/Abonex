// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Workspace {

 String get id; String? get name; String? get country; String? get defaultCurrency; List<String> get extraCurrencies; bool get configured;
/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceCopyWith<Workspace> get copyWith => _$WorkspaceCopyWithImpl<Workspace>(this as Workspace, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Workspace&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.country, country) || other.country == country)&&(identical(other.defaultCurrency, defaultCurrency) || other.defaultCurrency == defaultCurrency)&&const DeepCollectionEquality().equals(other.extraCurrencies, extraCurrencies)&&(identical(other.configured, configured) || other.configured == configured));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,country,defaultCurrency,const DeepCollectionEquality().hash(extraCurrencies),configured);

@override
String toString() {
  return 'Workspace(id: $id, name: $name, country: $country, defaultCurrency: $defaultCurrency, extraCurrencies: $extraCurrencies, configured: $configured)';
}


}

/// @nodoc
abstract mixin class $WorkspaceCopyWith<$Res>  {
  factory $WorkspaceCopyWith(Workspace value, $Res Function(Workspace) _then) = _$WorkspaceCopyWithImpl;
@useResult
$Res call({
 String id, String? name, String? country, String? defaultCurrency, List<String> extraCurrencies, bool configured
});




}
/// @nodoc
class _$WorkspaceCopyWithImpl<$Res>
    implements $WorkspaceCopyWith<$Res> {
  _$WorkspaceCopyWithImpl(this._self, this._then);

  final Workspace _self;
  final $Res Function(Workspace) _then;

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = freezed,Object? country = freezed,Object? defaultCurrency = freezed,Object? extraCurrencies = null,Object? configured = null,}) {
  return _then(Workspace(
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


/// Adds pattern-matching-related methods to [Workspace].
extension WorkspacePatterns on Workspace {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Workspace value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Workspace() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Workspace value)  $default,){
final _that = this;
switch (_that) {
case _Workspace():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Workspace value)?  $default,){
final _that = this;
switch (_that) {
case _Workspace() when $default != null:
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
case _Workspace() when $default != null:
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
case _Workspace():
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
case _Workspace() when $default != null:
return $default(_that.id,_that.name,_that.country,_that.defaultCurrency,_that.extraCurrencies,_that.configured);case _:
  return null;

}
}

}

/// @nodoc


class _Workspace extends Workspace {
  const _Workspace({required this.id, this.name, this.country, this.defaultCurrency,  List<String> extraCurrencies = const [], this.configured = false}): _extraCurrencies = extraCurrencies,super._();
  

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

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceCopyWith<_Workspace> get copyWith => __$WorkspaceCopyWithImpl<_Workspace>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Workspace&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.country, country) || other.country == country)&&(identical(other.defaultCurrency, defaultCurrency) || other.defaultCurrency == defaultCurrency)&&const DeepCollectionEquality().equals(other._extraCurrencies, _extraCurrencies)&&(identical(other.configured, configured) || other.configured == configured));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,country,defaultCurrency,const DeepCollectionEquality().hash(_extraCurrencies),configured);

@override
String toString() {
  return 'Workspace(id: $id, name: $name, country: $country, defaultCurrency: $defaultCurrency, extraCurrencies: $extraCurrencies, configured: $configured)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceCopyWith<$Res> implements $WorkspaceCopyWith<$Res> {
  factory _$WorkspaceCopyWith(_Workspace value, $Res Function(_Workspace) _then) = __$WorkspaceCopyWithImpl;
@override @useResult
$Res call({
 String id, String? name, String? country, String? defaultCurrency, List<String> extraCurrencies, bool configured
});




}
/// @nodoc
class __$WorkspaceCopyWithImpl<$Res>
    implements _$WorkspaceCopyWith<$Res> {
  __$WorkspaceCopyWithImpl(this._self, this._then);

  final _Workspace _self;
  final $Res Function(_Workspace) _then;

/// Create a copy of Workspace
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = freezed,Object? country = freezed,Object? defaultCurrency = freezed,Object? extraCurrencies = null,Object? configured = null,}) {
  return _then(_Workspace(
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

/// @nodoc
mixin _$User {

 String get id; String get email; UserRole get role; String? get firstName; String? get lastName; String? get language; Workspace? get workspace;
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCopyWith<User> get copyWith => _$UserCopyWithImpl<User>(this as User, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is User&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.role, role) || other.role == role)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.language, language) || other.language == language)&&(identical(other.workspace, workspace) || other.workspace == workspace));
}


@override
int get hashCode => Object.hash(runtimeType,id,email,role,firstName,lastName,language,workspace);

@override
String toString() {
  return 'User(id: $id, email: $email, role: $role, firstName: $firstName, lastName: $lastName, language: $language, workspace: $workspace)';
}


}

/// @nodoc
abstract mixin class $UserCopyWith<$Res>  {
  factory $UserCopyWith(User value, $Res Function(User) _then) = _$UserCopyWithImpl;
@useResult
$Res call({
 String id, String email, UserRole role, String? firstName, String? lastName, String? language, Workspace? workspace
});


$WorkspaceCopyWith<$Res>? get workspace;

}
/// @nodoc
class _$UserCopyWithImpl<$Res>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._self, this._then);

  final User _self;
  final $Res Function(User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? email = null,Object? role = null,Object? firstName = freezed,Object? lastName = freezed,Object? language = freezed,Object? workspace = freezed,}) {
  return _then(User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,workspace: freezed == workspace ? _self.workspace : workspace // ignore: cast_nullable_to_non_nullable
as Workspace?,
  ));
}
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkspaceCopyWith<$Res>? get workspace {
    if (_self.workspace == null) {
    return null;
  }

  return $WorkspaceCopyWith<$Res>(_self.workspace!, (value) {
    return _then(_self.copyWith(workspace: value));
  });
}
}


/// Adds pattern-matching-related methods to [User].
extension UserPatterns on User {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _User value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _User value)  $default,){
final _that = this;
switch (_that) {
case _User():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _User value)?  $default,){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String email,  UserRole role,  String? firstName,  String? lastName,  String? language,  Workspace? workspace)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String email,  UserRole role,  String? firstName,  String? lastName,  String? language,  Workspace? workspace)  $default,) {final _that = this;
switch (_that) {
case _User():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String email,  UserRole role,  String? firstName,  String? lastName,  String? language,  Workspace? workspace)?  $default,) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.email,_that.role,_that.firstName,_that.lastName,_that.language,_that.workspace);case _:
  return null;

}
}

}

/// @nodoc


class _User extends User {
  const _User({required this.id, required this.email, required this.role, this.firstName, this.lastName, this.language, this.workspace}): super._();
  

@override final  String id;
@override final  String email;
@override final  UserRole role;
@override final  String? firstName;
@override final  String? lastName;
@override final  String? language;
@override final  Workspace? workspace;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCopyWith<_User> get copyWith => __$UserCopyWithImpl<_User>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _User&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.role, role) || other.role == role)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.language, language) || other.language == language)&&(identical(other.workspace, workspace) || other.workspace == workspace));
}


@override
int get hashCode => Object.hash(runtimeType,id,email,role,firstName,lastName,language,workspace);

@override
String toString() {
  return 'User(id: $id, email: $email, role: $role, firstName: $firstName, lastName: $lastName, language: $language, workspace: $workspace)';
}


}

/// @nodoc
abstract mixin class _$UserCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$UserCopyWith(_User value, $Res Function(_User) _then) = __$UserCopyWithImpl;
@override @useResult
$Res call({
 String id, String email, UserRole role, String? firstName, String? lastName, String? language, Workspace? workspace
});


@override $WorkspaceCopyWith<$Res>? get workspace;

}
/// @nodoc
class __$UserCopyWithImpl<$Res>
    implements _$UserCopyWith<$Res> {
  __$UserCopyWithImpl(this._self, this._then);

  final _User _self;
  final $Res Function(_User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = null,Object? role = null,Object? firstName = freezed,Object? lastName = freezed,Object? language = freezed,Object? workspace = freezed,}) {
  return _then(_User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,firstName: freezed == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String?,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,workspace: freezed == workspace ? _self.workspace : workspace // ignore: cast_nullable_to_non_nullable
as Workspace?,
  ));
}

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkspaceCopyWith<$Res>? get workspace {
    if (_self.workspace == null) {
    return null;
  }

  return $WorkspaceCopyWith<$Res>(_self.workspace!, (value) {
    return _then(_self.copyWith(workspace: value));
  });
}
}

// dart format on
