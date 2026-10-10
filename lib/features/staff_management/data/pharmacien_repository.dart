import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../../../models/pharmacien.dart';
import '../../../models/utilisateur.dart';
import '../domain/staff_models.dart';

/// Pharmaciens (table `pharmaciens`).
class PharmacienRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  /// Recherche : nom, prénom, matricule, téléphone, email.
  Future<List<PharmacienDetail>> rechercher({String texte = ''}) async {
    final Database db = await _db;
    final String t = texte.trim();
    final List<Object?> args = [Role.pharmacien.name];
    String where = '';
    if (t.isNotEmpty) {
      where = 'WHERE p.nom LIKE ? OR p.prenom LIKE ? OR p.matricule LIKE ? '
          'OR p.telephone LIKE ? OR p.email LIKE ?';
      for (int k = 0; k < 5; k++) {
        args.add('%$t%');
      }
    }

    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT p.*,
        EXISTS (SELECT 1 FROM utilisateurs u
                WHERE u.role = ? AND u.ref_id = p.id) AS a_compte
      FROM pharmaciens p
      $where
      ORDER BY p.nom COLLATE NOCASE, p.prenom COLLATE NOCASE
    ''', args);

    final List<PharmacienDetail> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(PharmacienDetail(
        pharmacien: Pharmacien.fromMap(r),
        aCompte: (r['a_compte'] as int?) == 1,
      ));
    }
    return res;
  }

  Future<Pharmacien?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('pharmaciens', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Pharmacien.fromMap(rows.first);
  }

  Future<bool> matriculeExiste(String matricule, {int? exclureId}) =>
      _existe('matricule', matricule, exclureId);

  Future<bool> emailExiste(String email, {int? exclureId}) =>
      _existe('email', email.trim().toLowerCase(), exclureId);

  Future<bool> _existe(String colonne, String valeur, int? exclureId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'pharmaciens',
      columns: ['id'],
      where: '$colonne = ? AND id != ?',
      whereArgs: [valeur, exclureId ?? -1],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> inserer(Pharmacien p, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('pharmaciens', p.toMap());
  }

  Future<void> modifier(Pharmacien p, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('pharmaciens', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> supprimer(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('pharmaciens', where: 'id = ?', whereArgs: [id]);
  }
}
