import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../../../models/infirmier.dart';
import '../../../models/utilisateur.dart';
import '../domain/staff_models.dart';

/// Infirmiers (table `infirmiers`).
class InfirmierRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  /// Recherche : nom, prénom, matricule, téléphone, email.
  Future<List<InfirmierDetail>> rechercher({String texte = ''}) async {
    final Database db = await _db;
    final String t = texte.trim();
    final List<Object?> args = [Role.infirmier.name];
    String where = '';
    if (t.isNotEmpty) {
      where = 'WHERE i.nom LIKE ? OR i.prenom LIKE ? OR i.matricule LIKE ? '
          'OR i.telephone LIKE ? OR i.email LIKE ?';
      for (int k = 0; k < 5; k++) {
        args.add('%$t%');
      }
    }

    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT i.*,
        s.nom AS service_nom,
        EXISTS (SELECT 1 FROM utilisateurs u
                WHERE u.role = ? AND u.ref_id = i.id) AS a_compte
      FROM infirmiers i
      LEFT JOIN services s ON s.id = i.service_id
      $where
      ORDER BY i.nom COLLATE NOCASE, i.prenom COLLATE NOCASE
    ''', args);

    final List<InfirmierDetail> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(InfirmierDetail(
        infirmier: Infirmier.fromMap(r),
        serviceNom: r['service_nom'] as String?,
        aCompte: (r['a_compte'] as int?) == 1,
      ));
    }
    return res;
  }

  Future<Infirmier?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('infirmiers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Infirmier.fromMap(rows.first);
  }

  Future<bool> matriculeExiste(String matricule, {int? exclureId}) =>
      _existe('matricule', matricule, exclureId);

  Future<bool> emailExiste(String email, {int? exclureId}) =>
      _existe('email', email.trim().toLowerCase(), exclureId);

  Future<bool> _existe(String colonne, String valeur, int? exclureId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'infirmiers',
      columns: ['id'],
      where: '$colonne = ? AND id != ?',
      whereArgs: [valeur, exclureId ?? -1],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> inserer(Infirmier i, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('infirmiers', i.toMap());
  }

  Future<void> modifier(Infirmier i, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('infirmiers', i.toMap(), where: 'id = ?', whereArgs: [i.id]);
  }

  Future<void> supprimer(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('infirmiers', where: 'id = ?', whereArgs: [id]);
  }
}
