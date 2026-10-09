import 'package:sqflite/sqflite.dart';

import '../domain/models/ligne_ordonnance.dart';
import 'prescriptions_schema.dart';

class LigneOrdonnanceRepository {
  Future<Database> get _db => PrescriptionsSchema.database;

  Future<List<LigneOrdonnance>> parOrdonnance(int ordonnanceId, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    final List<Map<String, Object?>> rows = await e.query(
      'ligne_ordonnance',
      where: 'ordonnance_id = ?',
      whereArgs: [ordonnanceId],
      orderBy: 'id',
    );
    final List<LigneOrdonnance> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(LigneOrdonnance.fromMap(r));
    }
    return res;
  }

  Future<LigneOrdonnance?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('ligne_ordonnance', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : LigneOrdonnance.fromMap(rows.first);
  }

  /// Contrôle « Cette DCI figure déjà dans l'ordonnance ».
  Future<bool> dciPresente(int ordonnanceId, String dci, {int? exclureLigneId}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT l.id FROM ligne_ordonnance l
      JOIN medicament m ON m.id = l.medicament_id
      WHERE l.ordonnance_id = ? AND m.dci = ? COLLATE NOCASE AND l.id != ?
      LIMIT 1
    ''', [ordonnanceId, dci, exclureLigneId ?? -1]);
    return rows.isNotEmpty;
  }

  Future<int> inserer(LigneOrdonnance l, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('ligne_ordonnance', l.toMap());
  }

  /// Brouillon uniquement (déclencheur trg_ligne_verrou).
  Future<void> modifier(LigneOrdonnance l, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('ligne_ordonnance', l.toMap(), where: 'id = ?', whereArgs: [l.id]);
  }

  /// Délivrance : seule colonne modifiable après validation.
  Future<void> enregistrerDelivrance(int id, int quantiteDelivree, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update(
      'ligne_ordonnance',
      {'quantite_delivree': quantiteDelivree},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Brouillon uniquement (déclencheur trg_ligne_suppression_verrou).
  Future<void> supprimer(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('ligne_ordonnance', where: 'id = ?', whereArgs: [id]);
  }
}
