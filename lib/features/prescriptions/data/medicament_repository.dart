import 'package:sqflite/sqflite.dart';

import '../domain/models/medicament.dart';
import '../domain/regles_stock.dart';
import 'prescriptions_schema.dart';

class MedicamentRepository {
  Future<Database> get _db => PrescriptionsSchema.database;

  /// Recherche par nom ou DCI, filtres catégorie et générique, tri par prix.
  Future<List<Medicament>> lister({
    String texte = '',
    CategorieMedicament? categorie,
    bool? generique,
    bool inclureArchives = false,
    bool triParPrix = false,
  }) async {
    final Database db = await _db;
    final List<String> conditions = [];
    final List<Object?> args = [];

    if (!inclureArchives) {
      conditions.add('actif = 1');
    }
    final String t = texte.trim();
    if (t.isNotEmpty) {
      conditions.add('(nom_commercial LIKE ? OR dci LIKE ?)');
      args.add('%$t%');
      args.add('%$t%');
    }
    if (categorie != null) {
      conditions.add('categorie = ?');
      args.add(categorie.valeur);
    }
    if (generique != null) {
      conditions.add('generique = ?');
      args.add(generique ? 1 : 0);
    }

    final List<Map<String, Object?>> rows = await db.query(
      'medicament',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: triParPrix ? 'prix_public' : 'nom_commercial COLLATE NOCASE',
    );
    return _liste(rows);
  }

  Future<Medicament?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('medicament', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Medicament.fromMap(rows.first);
  }

  /// Plusieurs médicaments d'un coup (lignes d'une ordonnance).
  Future<Map<int, Medicament>> parIds(List<int> ids) async {
    final Map<int, Medicament> res = {};
    if (ids.isEmpty) {
      return res;
    }
    final Database db = await _db;
    final String marques = List<String>.filled(ids.length, '?').join(', ');
    final List<Map<String, Object?>> rows =
        await db.query('medicament', where: 'id IN ($marques)', whereArgs: ids);
    for (final Map<String, Object?> r in rows) {
      final Medicament m = Medicament.fromMap(r);
      res[m.id!] = m;
    }
    return res;
  }

  Future<Medicament?> parCodeBarres(String code) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'medicament',
      where: 'code_barres = ?',
      whereArgs: [code.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : Medicament.fromMap(rows.first);
  }

  /// Équivalents du catalogue local (même DCI, dosage et forme), du moins cher
  /// au plus cher : base de la substitution générique.
  Future<List<Medicament>> equivalents(Medicament m) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'medicament',
      where: 'actif = 1 AND id != ? AND dci = ? COLLATE NOCASE '
          'AND dosage = ? COLLATE NOCASE AND forme = ? COLLATE NOCASE',
      whereArgs: [m.id ?? -1, m.dci, m.dosage, m.forme],
      orderBy: 'prix_public',
    );
    return _liste(rows);
  }

  Future<bool> codeBarresExiste(String code, {int? exclureId}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'medicament',
      columns: ['id'],
      where: 'code_barres = ? AND id != ?',
      whereArgs: [code.trim(), exclureId ?? -1],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Déjà prescrit : archivage au lieu de suppression.
  Future<bool> estDejaPrescrit(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'ligne_ordonnance',
      columns: ['id'],
      where: 'medicament_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> inserer(Medicament m, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('medicament', m.toMap());
  }

  Future<void> modifier(Medicament m, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('medicament', m.toMap(), where: 'id = ?', whereArgs: [m.id]);
  }

  Future<void> mettreAJourRxcui(int id, String rxcui) async {
    final Database db = await _db;
    await db.update('medicament', {'rxcui': rxcui}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> archiver(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('medicament', {'actif': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> supprimer(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('medicament', where: 'id = ?', whereArgs: [id]);
  }

  // ----- Stock de la pharmacie -----

  /// Médicaments du catalogue avec leur stock, ruptures et stocks faibles
  /// d'abord ; [niveau] filtre (rupture, faible, normal).
  Future<List<Medicament>> stock({String texte = '', NiveauStock? niveau}) async {
    final Database db = await _db;
    final List<String> conditions = ['actif = 1'];
    final List<Object?> args = [];
    final String t = texte.trim();
    if (t.isNotEmpty) {
      conditions.add('(nom_commercial LIKE ? OR dci LIKE ? OR code_barres = ?)');
      args.add('%$t%');
      args.add('%$t%');
      args.add(t);
    }
    if (niveau == NiveauStock.rupture) {
      conditions.add('stock <= 0');
    } else if (niveau == NiveauStock.faible) {
      conditions.add('stock > 0 AND stock <= ?');
      args.add(ReglesStock.seuilFaible);
    } else if (niveau == NiveauStock.normal) {
      conditions.add('stock > ?');
      args.add(ReglesStock.seuilFaible);
    }
    final List<Map<String, Object?>> rows = await db.query(
      'medicament',
      where: conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'stock > ${ReglesStock.seuilFaible}, stock, nom_commercial COLLATE NOCASE',
    );
    return _liste(rows);
  }

  /// Nombre de médicaments en rupture et en stock faible.
  Future<({int ruptures, int faibles})> alertesStock() async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT SUM(CASE WHEN stock <= 0 THEN 1 ELSE 0 END) AS ruptures, '
      'SUM(CASE WHEN stock > 0 AND stock <= ? THEN 1 ELSE 0 END) AS faibles '
      'FROM medicament WHERE actif = 1',
      [ReglesStock.seuilFaible],
    );
    final Map<String, Object?> r = rows.first;
    return (ruptures: (r['ruptures'] as int?) ?? 0, faibles: (r['faibles'] as int?) ?? 0);
  }

  /// Entrée de stock (réception d'une commande).
  Future<void> ajouterStock(int id, int boites, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.rawUpdate('UPDATE medicament SET stock = stock + ? WHERE id = ?', [boites, id]);
  }

  /// Sortie de stock (délivrance) : false si le stock ne suffit pas.
  Future<bool> retirerStock(int id, int boites, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    final int n = await e.rawUpdate(
      'UPDATE medicament SET stock = stock - ? WHERE id = ? AND stock >= ?',
      [boites, id, boites],
    );
    return n == 1;
  }

  // ----- DCI (médicaments couverts par une APCI) -----

  /// DCI du catalogue → noms commerciaux (« metformine » → Glucophage, …).
  Future<Map<String, List<String>>> nomsParDci() async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'medicament',
      columns: ['dci', 'nom_commercial'],
      where: 'actif = 1',
      orderBy: 'dci COLLATE NOCASE, generique, nom_commercial COLLATE NOCASE',
    );
    final Map<String, List<String>> res = {};
    for (final Map<String, Object?> r in rows) {
      final String dci = r['dci'] as String;
      res.putIfAbsent(dci, () => <String>[]).add(r['nom_commercial'] as String);
    }
    return res;
  }

  List<Medicament> _liste(List<Map<String, Object?>> rows) {
    final List<Medicament> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Medicament.fromMap(r));
    }
    return res;
  }
}
