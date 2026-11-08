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
      case Err(failure: final f) when f is TwoFaRequired:
        // 2FA : la page passe en saisie du code — le pre_token
        // transite via fieldErrors['_2fa'] (pas de nouvel état).
        emit(
          LoginState.failure(
            message: '',
            fieldErrors: {'_2fa': f.preToken},
          ),
        );
      case Err(failure: final failure):
        emit(
          LoginState.failure(
            message: failure.localizedMessage,
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

  /// 2FA : 2ᵉ étape — code TOTP + pre_token → session complète.
  Future<void> verify2fa({
    required String preToken,
    required String code,
  }) async {
    if (state is LoginSubmitting) return;
    emit(const LoginState.submitting());
    final result = await _repository.verify2fa(
      preToken: preToken,
      code: code,
    );
    switch (result) {
      case Ok(value: final user):
        _authCubit.onAuthenticated(user);
        emit(const LoginState.idle());
      case Err(failure: final failure):
        emit(
          LoginState.failure(
            message: failure.localizedMessage,
            fieldErrors: {'_2fa': preToken},
          ),
        );
    }
  }
}
