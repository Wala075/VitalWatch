import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../../../core/utils/password_hasher.dart';
import '../../../models/utilisateur.dart';
import '../domain/staff_models.dart';

/// Comptes de connexion (table `utilisateurs`) liés aux médecins / patients.
class CompteRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  /// Email déjà utilisé par un autre compte que (role, refId).
  Future<bool> emailExiste(String email, {Role? role, int? refId}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'utilisateurs',
      columns: ['id'],
      where: "email = ? AND NOT (role = ? AND IFNULL(ref_id, -1) = ?)",
      whereArgs: [email.trim().toLowerCase(), role?.name ?? '', refId ?? -2],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> existe({
    required Role role,
    required int refId,
    DatabaseExecutor? exec,
  }) async {
    final DatabaseExecutor e = exec ?? await _db;
    final List<Map<String, Object?>> rows = await e.query(
      'utilisateurs',
      columns: ['id'],
      where: 'role = ? AND ref_id = ?',
      whereArgs: [role.name, refId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Crée le compte avec un mot de passe temporaire haché.
  /// Renvoie le mot de passe en clair UNE seule fois (pour l'envoi par mail).
  Future<CompteCree> creer({
    required String email,
    required Role role,
    required int refId,
    required String nom,
    required String prenom,
    DatabaseExecutor? exec,
  }) async {
    final DatabaseExecutor e = exec ?? await _db;
    final String motDePasse = PasswordHasher.genererMotDePasseTemporaire();
    final Utilisateur u = Utilisateur(
      email: email.trim().toLowerCase(),
      motDePasseHash: PasswordHasher.hacher(motDePasse),
      role: role,
      refId: refId,
      nom: nom,
      prenom: prenom,
    );
    await e.insert('utilisateurs', u.toMap());
    return CompteCree(
      email: u.email,
      motDePasseTemporaire: motDePasse,
      nom: u.nomComplet,
      role: role.libelle,
    );
  }

  Future<void> mettreAJour({
    required Role role,
    required int refId,
    required String email,
    required String nom,
    required String prenom,
    DatabaseExecutor? exec,
  }) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update(
      'utilisateurs',
      {'email': email.trim().toLowerCase(), 'nom': nom, 'prenom': prenom},
      where: 'role = ? AND ref_id = ?',
      whereArgs: [role.name, refId],
    );
  }

  Future<void> supprimer({
    required Role role,
    required int refId,
    DatabaseExecutor? exec,
  }) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete(
      'utilisateurs',
      where: 'role = ? AND ref_id = ?',
      whereArgs: [role.name, refId],
    );
  }
}
