import '../../../../core/utils/result.dart';
import '../entities/user.dart';

/// Contrat du repository d'authentification.
/// Le domaine définit l'interface ; la data l'implémente.
/// La présentation ne connaît que cette abstraction.
abstract class AuthRepository {
  /// Connexion email + mot de passe → tokens JWT persistés + user.
  Future<Result<User>> login({required String email, required String password});

  /// Inscription : crée le compte côté serveur puis ouvre la session
  /// (même contrat que login : tokens + user).
  Future<Result<User>> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? country,
  });

  /// User courant : /auth/me/ en priorité, cache local en fallback
  /// (permet d'ouvrir l'app hors-ligne avec le dernier profil connu).
  Future<Result<User>> currentUser();

  /// Un refresh token existe-t-il localement ?
  Future<bool> hasSession();

  /// Demande un email de réinitialisation. Toujours Ok côté UI
  /// (on ne révèle pas si l'email existe — bonne pratique sécu).
  Future<Result<void>> forgotPassword(String email);

  /// Blacklist le refresh côté serveur (best effort) + purge locale.
  Future<void> logout();
}
