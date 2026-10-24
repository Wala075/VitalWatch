import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../../../models/utilisateur.dart';
import '../domain/conges.dart';

/// Demandes de congé (table `conges`).
class CongeRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  static const String _select = '''
    SELECT c.*,
      CASE c.demandeur_role
        WHEN 'medecin' THEN 'Dr ' || m.prenom || ' ' || m.nom
        ELSE i.prenom || ' ' || i.nom
      END AS demandeur_nom,
      COALESCE(m.service_id, i.service_id) AS service_id,
      s.nom AS service_nom
    FROM conges c
    LEFT JOIN medecins m ON c.demandeur_role = 'medecin' AND m.id = c.demandeur_id
    LEFT JOIN infirmiers i ON c.demandeur_role = 'infirmier' AND i.id = c.demandeur_id
    LEFT JOIN services s ON s.id = COALESCE(m.service_id, i.service_id)
  ''';

  CongeDetail _lire(Map<String, Object?> r) {
    return CongeDetail(
      conge: Conge.fromMap(r),
      nom: r['demandeur_nom'] as String?,
      serviceId: r['service_id'] as int?,
      serviceNom: r['service_nom'] as String?,
    );
  }

  /// Demandes à traiter d'abord, puis les plus récentes.
  Future<List<CongeDetail>> lister({
    StatutConge? statut,
    Role? role,
    int? demandeurId,
  }) async {
    final Database db = await _db;
    final List<String> conditions = [];
    final List<Object?> args = [];
    if (statut != null) {
      conditions.add('c.statut = ?');
      args.add(statut.code);
    }
    if (role != null) {
      conditions.add('c.demandeur_role = ?');
      args.add(role.name);
    }
    if (demandeurId != null) {
      conditions.add('c.demandeur_id = ?');
      args.add(demandeurId);
    }
    final String where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      $_select
      $where
      ORDER BY CASE c.statut WHEN 'en_attente' THEN 0 ELSE 1 END,
        c.date_debut DESC
    ''', args);
    return [for (final Map<String, Object?> r in rows) _lire(r)];
  }

  Future<CongeDetail?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('$_select WHERE c.id = ? LIMIT 1', [id]);
    return rows.isEmpty ? null : _lire(rows.first);
  }

  /// Demandes d'une personne, filtrées par statut.
  Future<List<Conge>> dePersonne(
    Role role,
    int id, {
    List<StatutConge> statuts = const [StatutConge.validee],
  }) async {
    final Database db = await _db;
    final String marques = List<String>.filled(statuts.length, '?').join(', ');
    final List<Map<String, Object?>> rows = await db.query(
      'conges',
      where: 'demandeur_role = ? AND demandeur_id = ? AND statut IN ($marques)',
      whereArgs: [role.name, id, for (final StatutConge s in statuts) s.code],
      orderBy: 'date_debut',
    );
    return [for (final Map<String, Object?> r in rows) Conge.fromMap(r)];
  }

  /// Personnes en congé validé aujourd'hui → dernier jour du congé.
  Future<Map<int, DateTime>> enCongeAujourdhui(Role role) async {
    final Database db = await _db;
    final String aujourdHui = RegleConges.iso(DateTime.now());
    final List<Map<String, Object?>> rows = await db.query(
      'conges',
      columns: ['demandeur_id', 'date_fin'],
      where: "demandeur_role = ? AND statut = 'validee' "
          'AND date_debut <= ? AND date_fin >= ?',
      whereArgs: [role.name, aujourdHui, aujourdHui],
    );
    final Map<int, DateTime> res = {};
    for (final Map<String, Object?> r in rows) {
      final int id = r['demandeur_id'] as int;
      final DateTime fin = DateTime.parse(r['date_fin'] as String);
      final DateTime? actuelle = res[id];
      if (actuelle == null || fin.isAfter(actuelle)) res[id] = fin;
    }
    return res;
  }

  Future<int> compterEnAttente() async {
    final Database db = await _db;
    return Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM conges WHERE statut = 'en_attente'",
        )) ??
        0;
  }

  Future<int> inserer(Conge c) async {
    final Database db = await _db;
    return db.insert('conges', {
      ...c.toMap(),
      'cree_le': DateTime.now().toIso8601String(),
    });
  }

  Future<void> changerStatut(int id, StatutConge statut, {String? commentaire}) async {
    final Database db = await _db;
    await db.update(
      'conges',
      {
        'statut': statut.code,
        'commentaire': commentaire,
        'decide_le': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// À la suppression d'un médecin / infirmier.
  Future<void> supprimerDe(Role role, int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete(
      'conges',
      where: 'demandeur_role = ? AND demandeur_id = ?',
      whereArgs: [role.name, id],
    );
  }
}
