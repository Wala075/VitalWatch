import 'package:sqflite/sqflite.dart';

import '../domain/dispatch_models.dart';
import '../domain/models/ambulancier.dart';
import 'ambulance_schema.dart';

class AmbulancierRepository {
  Future<Database> get _db => AmbulanceSchema.database;

  Future<List<AmbulancierDetail>> rechercher({
    String texte = '',
    int? ambulanceId,
    RoleAmbulancier? role,
    bool? disponible,
  }) async {
    final Database db = await _db;
    final List<String> conditions = [];
    final List<Object?> args = [];
    final String t = texte.trim();
    if (t.isNotEmpty) {
      conditions.add('(e.nom LIKE ? OR e.telephone LIKE ?)');
      args.add('%$t%');
      args.add('%$t%');
    }
    if (ambulanceId != null) {
      conditions.add('e.ambulance_id = ?');
      args.add(ambulanceId);
    }
    if (role != null) {
      conditions.add('e.role = ?');
      args.add(role.code);
    }
    if (disponible != null) {
      conditions.add('e.disponible = ?');
      args.add(disponible ? 1 : 0);
    }
    final String where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT e.*, a.immatriculation
      FROM ambulanciers e
      LEFT JOIN ambulances a ON a.id = e.ambulance_id
      $where
      ORDER BY e.nom COLLATE NOCASE
    ''', args);

    final List<AmbulancierDetail> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(AmbulancierDetail(
        ambulancier: Ambulancier.fromMap(r),
        immatriculation: r['immatriculation'] as String?,
      ));
    }
    return res;
  }

  Future<Ambulancier?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('ambulanciers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Ambulancier.fromMap(rows.first);
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

  Future<int> compterAffectes(int ambulanceId, {bool disponiblesSeulement = false}) async {
    final Database db = await _db;
    final String filtre = disponiblesSeulement ? ' AND disponible = 1' : '';
    return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ambulanciers WHERE ambulance_id = ?$filtre',
          [ambulanceId],
        )) ??
        0;
  }

  Future<int> inserer(Ambulancier a) async {
    final Database db = await _db;
    return db.insert('ambulanciers', a.toMap());
  }

  Future<void> modifier(Ambulancier a) async {
    final Database db = await _db;
    await db.update('ambulanciers', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  }

  Future<void> supprimer(int id) async {
    final Database db = await _db;
    await db.delete('ambulanciers', where: 'id = ?', whereArgs: [id]);
  }
}
