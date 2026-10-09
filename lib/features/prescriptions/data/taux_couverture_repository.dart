import 'package:sqflite/sqflite.dart';

import '../domain/models/taux_couverture.dart';
import 'prescriptions_schema.dart';

class TauxCouvertureRepository {
  Future<Database> get _db => PrescriptionsSchema.database;

  Future<List<TauxCouverture>> parAssurance(int assuranceId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'taux_couverture',
      where: 'assurance_id = ?',
      whereArgs: [assuranceId],
      orderBy: 'categorie',
    );
    final List<TauxCouverture> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(TauxCouverture.fromMap(r));
    }
    return res;
  }

  /// Taux de la catégorie, sinon celui de « tous », sinon null (pas de prise en charge).
  Future<double?> taux(int assuranceId, String categorie) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'taux_couverture',
      columns: ['taux'],
      where: 'assurance_id = ? AND categorie IN (?, ?)',
      whereArgs: [assuranceId, categorie, TauxCouverture.tous],
      // La catégorie exacte (0) passe avant « tous » (1).
      orderBy: "categorie = '${TauxCouverture.tous}'",
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return (rows.first['taux'] as num).toDouble();
  }

  /// Remplace tous les taux d'une assurance (formulaire admin).
  Future<void> remplacer(int assuranceId, List<TauxCouverture> taux, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('taux_couverture', where: 'assurance_id = ?', whereArgs: [assuranceId]);
    for (final TauxCouverture t in taux) {
      await e.insert(
        'taux_couverture',
        TauxCouverture(assuranceId: assuranceId, categorie: t.categorie, taux: t.taux).toMap(),
      );
    }
  }

  /// Ajoute ou remplace le taux d'une catégorie.
  Future<void> enregistrer(TauxCouverture t, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.insert('taux_couverture', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> supprimer(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('taux_couverture', where: 'id = ?', whereArgs: [id]);
  }
}
