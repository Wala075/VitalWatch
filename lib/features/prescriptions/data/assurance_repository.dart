import 'package:sqflite/sqflite.dart';

import '../domain/models/assurance.dart';
import 'prescriptions_schema.dart';

class AssuranceRepository {
  Future<Database> get _db => PrescriptionsSchema.database;

  Future<List<Assurance>> lister() async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('assurance', orderBy: "type = 'cnam' DESC, nom COLLATE NOCASE");
    final List<Assurance> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Assurance.fromMap(r));
    }
    return res;
  }

  Future<Assurance?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('assurance', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Assurance.fromMap(rows.first);
  }

  Future<bool> nomExiste(String nom, {int? exclureId}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'assurance',
      columns: ['id'],
      where: 'nom = ? COLLATE NOCASE AND id != ?',
      whereArgs: [nom.trim(), exclureId ?? -1],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Suppression permise seulement si aucun contrat n'y est lié.
  Future<bool> aDesContrats(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'contrat_assurance',
      columns: ['id'],
      where: 'assurance_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> inserer(Assurance a, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('assurance', a.toMap());
  }

  Future<void> modifier(Assurance a, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('assurance', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  }

  /// Ses taux sont supprimés en cascade.
  Future<void> supprimer(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('assurance', where: 'id = ?', whereArgs: [id]);
  }
}
