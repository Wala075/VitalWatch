import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../../../models/ambulancier.dart';
import '../../../models/utilisateur.dart';
import '../domain/staff_models.dart';

/// Ambulanciers (table `ambulanciers`, partagée avec le module 3).
/// Le module 1 ne modifie jamais `ambulance_id` : l'affectation à une
/// ambulance est faite dans le module Ambulances.
class AmbulancierRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  static const String _select = '''
    SELECT a.*, u.email AS compte_email
    FROM ambulanciers a
    LEFT JOIN utilisateurs u ON u.role = ? AND u.ref_id = a.id
  ''';

  /// Recherche : nom, téléphone, email du compte.
  Future<List<AmbulancierCompte>> rechercher({String texte = ''}) async {
    final Database db = await _db;
    final String t = texte.trim();
    final List<Object?> args = [Role.ambulancier.name];
    String where = '';
    if (t.isNotEmpty) {
      where = 'WHERE a.nom LIKE ? OR a.telephone LIKE ? OR u.email LIKE ?';
      for (int k = 0; k < 3; k++) {
        args.add('%$t%');
      }
    }
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '$_select $where ORDER BY a.nom COLLATE NOCASE',
      args,
    );
    final List<AmbulancierCompte> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(_lire(r));
    }
    return res;
  }

  Future<AmbulancierCompte?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '$_select WHERE a.id = ? LIMIT 1',
      [Role.ambulancier.name, id],
    );
    return rows.isEmpty ? null : _lire(rows.first);
  }

  AmbulancierCompte _lire(Map<String, Object?> r) {
    return AmbulancierCompte(
      ambulancier: Ambulancier.fromMap(r),
      email: r['compte_email'] as String?,
    );
  }

  Future<bool> telephoneExiste(String telephone, {int? exclureId}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'ambulanciers',
      columns: ['id'],
      where: 'telephone = ? AND id != ?',
      whereArgs: [telephone, exclureId ?? -1],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> inserer(Ambulancier a, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('ambulanciers', a.toMap()..remove('ambulance_id'));
  }

  Future<void> modifier(Ambulancier a, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update(
      'ambulanciers',
      a.toMap()..remove('ambulance_id'),
      where: 'id = ?',
      whereArgs: [a.id],
    );
  }

  Future<void> supprimer(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('ambulanciers', where: 'id = ?', whereArgs: [id]);
  }
}
