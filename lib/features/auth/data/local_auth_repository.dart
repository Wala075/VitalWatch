import '../../../core/config/email_config.dart';
import '../../../core/services/app_database.dart';
import '../../../core/services/email_service.dart';
import '../../../core/utils/password_hasher.dart';
import '../../../models/utilisateur.dart';
import '../domain/auth_repository.dart';

/// Authentification sur la table SQLite `utilisateurs`
/// (comptes créés par le module Services & Personnel).
class LocalAuthRepository implements AuthRepository {
  static const String _erreurIdentifiants = 'Email ou mot de passe incorrect';

  @override
  Future<Utilisateur> login({
    required String email,
    required String motDePasse,
  }) async {
    final db = await AppDatabase.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      'utilisateurs',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AuthException(_erreurIdentifiants);
    }

    final Utilisateur u = Utilisateur.fromMap(rows.first);
    if (!PasswordHasher.verifier(motDePasse, u.motDePasseHash)) {
      throw const AuthException(_erreurIdentifiants);
    }
    if (!u.actif) {
      throw const AuthException(
        "Compte désactivé. Contactez l'administrateur.",
      );
    }
    return u;
  }

  /// Génère un nouveau mot de passe temporaire et l'envoie par mail.
  /// Le mot de passe n'est remplacé que si le mail est bien parti.
  @override
  Future<void> reinitialiserMotDePasse(String email) async {
    if (!EmailConfig.estConfigure) {
      throw const AuthException(
        "L'envoi de mail n'est pas configuré. Contactez l'administrateur.",
      );
    }

    final db = await AppDatabase.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      'utilisateurs',
      where: 'email = ? AND actif = 1',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) {
      return; // on ne révèle pas si le compte existe
    }

    final Utilisateur u = Utilisateur.fromMap(rows.first);
    final String motDePasse = PasswordHasher.genererMotDePasseTemporaire();
    final EnvoiEmail envoi = await EmailService().envoyerIdentifiants(
      email: u.email,
      nom: u.nomComplet,
      role: u.role.libelle,
      motDePasse: motDePasse,
      message: EmailService.messageReinitialisation,
    );
    if (!envoi.envoye) {
      throw AuthException(envoi.erreur ?? "Échec de l'envoi du mail");
    }

    await db.update(
      'utilisateurs',
      {'mot_de_passe_hash': PasswordHasher.hacher(motDePasse)},
      where: 'id = ?',
      whereArgs: [u.id],
    );
  }

  @override
  Future<void> logout() async {}
}
