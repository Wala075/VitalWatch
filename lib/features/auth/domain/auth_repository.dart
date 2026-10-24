import '../../../models/utilisateur.dart';

/// Erreur métier d'authentification (message affichable à l'utilisateur).
class AuthException implements Exception {
  const AuthException(
    this.message, {
    this.captchaRequis = false,
    this.bloque = false,
  });

  final String message;

  /// L'écran doit afficher le captcha avant le prochain essai.
  final bool captchaRequis;

  /// Connexion bloquée temporairement (trop d'échecs).
  final bool bloque;

  @override
  String toString() => message;
}

/// Contrat d'authentification : l'écran ne dépend que de cette interface.
/// Implémentation actuelle : LocalAuthRepository (SQLite).
abstract class AuthRepository {
  /// [jetonCaptcha] : jeton du captcha, exigé à chaque connexion.
  Future<Utilisateur> login({
    required String email,
    required String motDePasse,
    String? jetonCaptcha,
  });

  /// Captcha toujours exigé (protège l'envoi de mails).
  Future<void> reinitialiserMotDePasse(
    String email, {
    required String jetonCaptcha,
  });

  Future<void> logout();
}
