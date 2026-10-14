import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_state.freezed.dart';

/// État du FORMULAIRE de connexion — porté par LoginCubit.
/// Distinct de AuthState : le formulaire vit et meurt avec la page,
/// la session survit à tout le reste.
@freezed
sealed class LoginState with _$LoginState {
  /// Formulaire au repos, prêt à saisir.
  const factory LoginState.idle() = LoginIdle;

  /// Requête de connexion en cours → bouton en spinner,
  /// champs désactivés.
  const factory LoginState.submitting() = LoginSubmitting;

  /// Échec : message global + erreurs par champ éventuelles.
  const factory LoginState.failure({
    required String message,
    @Default({}) Map<String, String> fieldErrors,
  }) = LoginFailure;

  // Pas d'état "success" : en cas de succès c'est AuthCubit qui prend
  // le relais, et le guard du router redirige vers l'accueil.
}
