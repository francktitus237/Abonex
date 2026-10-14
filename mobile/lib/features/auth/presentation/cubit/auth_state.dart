import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/user.dart';

part 'auth_state.freezed.dart';

/// État de la SESSION (connecté / pas connecté) — porté par AuthCubit.
/// Union freezed `sealed` → switch exhaustif garanti par le compilateur.
@freezed
sealed class AuthState with _$AuthState {
  /// Au démarrage : on ne sait pas encore si une session existe.
  const factory AuthState.unknown() = AuthUnknown;

  /// Pas de session valide → l'utilisateur doit se connecter.
  const factory AuthState.unauthenticated() = Unauthenticated;

  /// Session valide → le user et son rôle sont disponibles partout.
  const factory AuthState.authenticated(User user) = Authenticated;
}
