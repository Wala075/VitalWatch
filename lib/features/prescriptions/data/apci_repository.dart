import 'package:sqflite/sqflite.dart';

import '../domain/models/apci.dart';
import 'prescriptions_schema.dart';

class ApciRepository {
  Future<Database> get _db => PrescriptionsSchema.database;

  Future<List<Apci>> lister({String texte = ''}) async {
    final Database db = await _db;
    final String t = texte.trim();
    final List<Map<String, Object?>> rows = await db.query(
      'apci',
      where: t.isEmpty ? null : 'code_cim10 LIKE ? OR libelle LIKE ?',
      whereArgs: t.isEmpty ? null : ['%$t%', '%$t%'],
      orderBy: 'code_cim10',
    );
    final List<Apci> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Apci.fromMap(r));
    }
    return res;
  }

  Future<Apci?> parCode(String code) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'apci',
      where: 'code_cim10 = ?',
      whereArgs: [code.trim().toUpperCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : Apci.fromMap(rows.first);
  }

  /// Suppression permise seulement si aucun contrat ne la référence.
  Future<bool> estReferencee(String code) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'contrat_assurance',
      columns: ['id'],
      where: 'code_apci = ?',
      whereArgs: [code],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> inserer(Apci a, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.insert('apci', a.toMap());
  }

  /// Seul le libellé se modifie (le code est la clé).
  Future<void> modifierLibelle(String code, String libelle, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('apci', {'libelle': libelle.trim()}, where: 'code_cim10 = ?', whereArgs: [code]);
  }

  Future<void> supprimer(String code, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('apci', where: 'code_cim10 = ?', whereArgs: [code]);
  }
}
