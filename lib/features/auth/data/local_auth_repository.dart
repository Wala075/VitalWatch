import '../../../core/config/email_config.dart';
import '../../../core/services/app_database.dart';
import '../../../core/services/email_service.dart';
import '../../../core/utils/password_hasher.dart';
import '../../../models/utilisateur.dart';
import '../domain/auth_repository.dart';
import '../domain/protection_connexion.dart';
import 'captcha_api.dart';
import 'tentative_repository.dart';

/// Authentification sur la table SQLite `utilisateurs`
/// (comptes créés par le module Services & Personnel), protégée contre la
/// force brute (captcha Cloudflare Turnstile à chaque connexion, blocage
/// progressif à partir de 5 échecs : voir ProtectionConnexion).
class LocalAuthRepository implements AuthRepository {
  static const String _erreurIdentifiants = 'Email ou mot de passe incorrect';

  final TentativeRepository _tentatives = TentativeRepository();
  final CaptchaApi _captcha = CaptchaApi();

  @override
  Future<Utilisateur> login({
    required String email,
    required String motDePasse,
    String? jetonCaptcha,
  }) async {
    final String cle = email.trim().toLowerCase();
    final DateTime maintenant = DateTime.now();
    final TentativesConnexion etat = await _tentatives.lire(cle);

    final Duration? attente = ProtectionConnexion.attente(etat, maintenant);
    if (attente != null) {
      throw AuthException(
        'Trop de tentatives. Réessayez dans '
        '${ProtectionConnexion.formater(attente)}.',
        captchaRequis: true,
        bloque: true,
      );
    }
    await _verifierCaptcha(jetonCaptcha);

    final db = await AppDatabase.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      'utilisateurs',
      where: 'email = ?',
      whereArgs: [cle],
      limit: 1,
    );
    final Utilisateur? u = rows.isEmpty ? null : Utilisateur.fromMap(rows.first);

    // Email inconnu ou mot de passe faux : même message, même compteur.
    if (u == null || !PasswordHasher.verifier(motDePasse, u.motDePasseHash)) {
      final TentativesConnexion apres =
          ProtectionConnexion.apresEchec(etat, maintenant);
      await _tentatives.enregistrer(cle, apres);
      final Duration? blocage = ProtectionConnexion.attente(apres, maintenant);
      final String message = blocage != null
          ? '$_erreurIdentifiants. Trop de tentatives : connexion bloquée '
              '${ProtectionConnexion.formater(blocage)}.'
          : '$_erreurIdentifiants. Encore '
              '${ProtectionConnexion.essaisAvantBlocage(apres)} essai(s) avant '
              'un blocage temporaire.';
      throw AuthException(message, captchaRequis: true, bloque: blocage != null);
    }
    if (!u.actif) {
      throw const AuthException(
        "Compte désactivé. Contactez l'administrateur.",
      );
    }
    await _tentatives.effacer(cle);
    return u;
  }

  /// Vérification du jeton par l'API Cloudflare Turnstile.
  Future<void> _verifierCaptcha(String? jeton) async {
    final String j = jeton ?? '';
    if (j.isEmpty) {
      throw const AuthException(
        "Confirmez que vous n'êtes pas un robot.",
        captchaRequis: true,
      );
    }
    final VerificationCaptcha v = await _captcha.verifier(j);
    if (!v.valide) {
      throw AuthException(v.message, captchaRequis: true);
    }
  }

  /// Génère un nouveau mot de passe temporaire et l'envoie par mail.
  /// Le mot de passe n'est remplacé que si le mail est bien parti.
  @override
  Future<void> reinitialiserMotDePasse(
    String email, {
    required String jetonCaptcha,
  }) async {
    await _verifierCaptcha(jetonCaptcha);
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
