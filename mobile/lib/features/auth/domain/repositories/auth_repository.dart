import '../../../../core/utils/result.dart';
import '../entities/user.dart';

/// Contrat du repository d'authentification.
/// Le domaine définit l'interface ; la data l'implémente.
/// La présentation ne connaît que cette abstraction.
abstract class AuthRepository {
  /// Connexion email + mot de passe → tokens JWT persistés + user.
  Future<Result<User>> login({required String email, required String password});

  /// 2ᵉ étape du login 2FA : pre_token signé + code TOTP
  /// → session complète (étude Phase 4).
  Future<Result<User>> verify2fa({
    required String preToken,
    required String code,
  });

  /// Inscription : crée le compte côté serveur puis ouvre la session
  /// (même contrat que login : tokens + user).
  Future<Result<User>> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? country,
    String? kind,
  });

  /// User courant : /auth/me/ en priorité, cache local en fallback
  /// (permet d'ouvrir l'app hors-ligne avec le dernier profil connu).
  Future<Result<User>> currentUser();

  /// Met à jour le profil (prénom, nom, email, langue) et renvoie
  /// l'utilisateur à jour.
  Future<Result<User>> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? language,
  });

  /// Upload une photo de profil — [path] pointe un fichier image
  /// local (déjà redimensionné par la présentation).
  Future<Result<User>> uploadAvatar(String path);

  /// Retire la photo de profil (avatar = chaîne vide côté API).
  Future<Result<User>> removeAvatar();

  /// Met à jour la devise de base du workspace (owner/manager).
  Future<Result<User>> updateWorkspaceCurrency(String currency);

  /// Change le mot de passe : le serveur vérifie l'ancien.
  Future<Result<void>> changePassword(String current, String next);

  /// Un refresh token existe-t-il localement ?
  Future<bool> hasSession();

  /// Demande un email de réinitialisation. Toujours Ok côté UI
  /// (on ne révèle pas si l'email existe — bonne pratique sécu).
  Future<Result<void>> forgotPassword(String email);

  /// Blacklist le refresh côté serveur (best effort) + purge locale.
  Future<void> logout();
}
