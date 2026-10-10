import 'package:sqflite/sqflite.dart';

import '../domain/couverture_apci.dart';
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

  // ----- Médicaments couverts (table apci_medicament, par DCI) -----

  /// DCI couvertes par l'APCI, dans l'ordre alphabétique.
  Future<List<String>> dcis(String code) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'apci_medicament',
      columns: ['dci'],
      where: 'code_apci = ?',
      whereArgs: [code],
      orderBy: 'dci COLLATE NOCASE',
    );
    final List<String> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(r['dci'] as String);
    }
    return res;
  }

  /// Même liste, normalisée pour la comparaison (CouvertureApci).
  Future<Set<String>> dcisCouvertes(String code) async {
    final Set<String> res = {};
    for (final String d in await dcis(code)) {
      res.add(CouvertureApci.normaliser(d));
    }
    return res;
  }

  /// Code APCI → nombre de DCI couvertes (sous-titre de la liste).
  Future<Map<String, int>> nbDciParCode() async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT code_apci, COUNT(*) AS nb FROM apci_medicament GROUP BY code_apci',
    );
    final Map<String, int> res = {};
    for (final Map<String, Object?> r in rows) {
      res[r['code_apci'] as String] = r['nb'] as int;
    }
    return res;
  }

  /// Contrats (donc patients) qui portent cette APCI.
  Future<int> nbContrats(String code) async {
    final Database db = await _db;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM contrat_assurance WHERE code_apci = ?', [code]),
        ) ??
        0;
  }

  Future<void> lierDci(String code, String dci, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.insert(
      'apci_medicament',
      {'code_apci': code, 'dci': dci.trim()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> delierDci(String code, String dci, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('apci_medicament', where: 'code_apci = ? AND dci = ?', whereArgs: [code, dci]);
  }
}
