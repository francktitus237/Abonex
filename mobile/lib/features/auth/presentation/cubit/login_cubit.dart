import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_cubit.dart';
import 'login_state.dart';

/// Cubit du formulaire de connexion.
/// Créé à l'ouverture de la page, fermé à sa destruction (factory).
class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required this._repository, required this._authCubit})
    : super(const LoginState.idle());

  final AuthRepository _repository;
  final AuthCubit _authCubit;

  Future<void> submit({required String email, required String password}) async {
    // Double-tap sur le bouton → on ignore pendant la requête.
    if (state is LoginSubmitting) return;

    emit(const LoginState.submitting());
    final result = await _repository.login(
      email: email.trim(),
      password: password,
    );

    switch (result) {
      case Ok(value: final user):
        // AuthCubit est la source de vérité de la session ;
        // le guard du router redirigera vers l'accueil.
        _authCubit.onAuthenticated(user);
        emit(const LoginState.idle());
      case Err(failure: final failure):
        emit(
          LoginState.failure(
            message: failure.message,
            fieldErrors: failure is ValidationFailure
                ? failure.fieldErrors
                : const {},
          ),
        );
    }
  }

  /// Mot de passe oublié : le cubit retourne le Result, la page
  /// décide du toast à afficher (l'UI reste dans les widgets).
  Future<Result<void>> forgotPassword(String email) =>
      _repository.forgotPassword(email);
}
