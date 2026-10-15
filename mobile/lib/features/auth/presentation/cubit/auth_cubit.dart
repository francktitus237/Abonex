import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

/// Cubit de SESSION : source de vérité "qui est connecté ?".
/// Vit pendant toute la durée de l'app (singleton get_it).
/// Le router lit son état pour les guards, le profil l'affiche.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthState.unknown());

  final AuthRepository _repository;

  /// Appelé une seule fois au démarrage (main.dart), avant le 1er frame.
  /// Restaure la session si un refresh token existe.
  Future<void> bootstrap() async {
    if (!await _repository.hasSession()) {
      return emit(const AuthState.unauthenticated());
    }
    final result = await _repository.currentUser();
    emit(switch (result) {
      Ok(value: final user) => AuthState.authenticated(user),
      Err() => const AuthState.unauthenticated(),
    });
  }

  /// Appelé par LoginCubit après une connexion réussie.
  void onAuthenticated(User user) => emit(AuthState.authenticated(user));

  /// Inscription réelle via l'API : en cas de succès la session
  /// démarre immédiatement (tokens déjà persistés par le repository).
  Future<Result<User>> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? country,
  }) async {
    final result = await _repository.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      country: country,
    );
    if (result case Ok(value: final user)) {
      emit(AuthState.authenticated(user));
    }
    return result;
  }

  /// Appelé par l'intercepteur Dio quand le refresh token est mort
  /// (session expirée pendant l'usage) → retour forcé au login.
  void onSessionExpired() {
    if (state is! Unauthenticated) {
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthState.unauthenticated());
  }
}
