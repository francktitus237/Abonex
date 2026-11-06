import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/result.dart';
import '../../../subscriptions/presentation/cubit/subscriptions_cubit.dart';
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

  /// Re-synchronise le profil (/auth/me/) — re-tap onglet
  /// Profil, photo/mise à jour serveur, workspace modifié
  /// ailleurs. Silence en cas d'erreur réseau.
  Future<void> refresh() async {
    if (state is! Authenticated) return;
    final result = await _repository.currentUser();
    if (result case Ok(value: final user)) {
      emit(AuthState.authenticated(user));
    }
  }

  /// Appelé par LoginCubit après une connexion réussie.
  void onAuthenticated(User user) {
    // Nouveau compte : vider la liste de l'ancien workspace
    // et déverrouiller ensureLoaded pour recharger.
    getIt<SubscriptionsCubit>().resetForAccountChange();
    emit(AuthState.authenticated(user));
  }

  /// Inscription réelle via l'API : en cas de succès la session
  /// démarre immédiatement (tokens déjà persistés par le repository).
  Future<Result<User>> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? country,
    String? kind,
  }) async {
    final result = await _repository.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      country: country,
      kind: kind,
    );
    if (result case Ok(value: final user)) {
      getIt<SubscriptionsCubit>().resetForAccountChange();
      emit(AuthState.authenticated(user));
    }
    return result;
  }

  /// Met à jour le profil (prénom, nom, email, langue) côté serveur
  /// puis ré-émet l'utilisateur à jour.
  Future<Result<User>> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? language,
  }) async {
    return _emit(
      _repository.updateProfile(
        firstName: firstName,
        lastName: lastName,
        email: email,
        language: language,
      ),
    );
  }

  /// Upload une nouvelle photo de profil (fichier local).
  Future<Result<User>> uploadAvatar(String path) =>
      _emit(_repository.uploadAvatar(path));

  /// Retire la photo de profil.
  Future<Result<User>> removeAvatar() => _emit(_repository.removeAvatar());

  /// Change la devise de base du workspace (owner/manager).
  Future<Result<User>> updateWorkspaceCurrency(String currency) =>
      _emit(_repository.updateWorkspaceCurrency(currency));

  /// Change le mot de passe après vérification de l'ancien.
  Future<Result<void>> changePassword(String current, String next) =>
      _repository.changePassword(current, next);

  /// Factorisation : émet l'utilisateur à jour sur un Ok.
  Future<Result<User>> _emit(Future<Result<User>> call) async {
    final result = await call;
    if (result case Ok(value: final user)) {
      emit(AuthState.authenticated(user));
    }
    return result;
  }

  /// Appelé par l'intercepteur Dio quand le refresh token est mort
  /// (session expirée pendant l'usage) → retour forcé au login.
  void onSessionExpired() {
    if (state is! Unauthenticated) {
      getIt<SubscriptionsCubit>().resetForAccountChange();
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    getIt<SubscriptionsCubit>().resetForAccountChange();
    emit(const AuthState.unauthenticated());
  }
}
