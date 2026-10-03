import '../../../models/utilisateur.dart';

/// Erreur métier d'authentification (message affichable à l'utilisateur).
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Contrat d'authentification : l'écran ne dépend que de cette interface.
/// Implémentation actuelle : LocalAuthRepository (SQLite).
abstract class AuthRepository {
  Future<Utilisateur> login({
    required String email,
    required String motDePasse,
  });

  Future<void> reinitialiserMotDePasse(String email);

  Future<void> logout();
}
