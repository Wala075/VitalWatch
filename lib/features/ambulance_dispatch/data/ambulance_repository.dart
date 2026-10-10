import 'package:sqflite/sqflite.dart';

import '../domain/dispatch_models.dart';
import '../domain/models/ambulance.dart';
import 'ambulance_schema.dart';

class AmbulanceRepository {
  Future<Database> get _db => AmbulanceSchema.database;

  Future<List<Ambulance>> lister({StatutAmbulance? statut}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'ambulances',
      where: statut == null ? null : 'statut = ?',
      whereArgs: statut == null ? null : [statut.code],
      orderBy: 'immatriculation',
    );
    final List<Ambulance> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Ambulance.fromMap(r));
    }
    return res;
  }

  /// Flotte avec équipage, nombre de missions et seuil d'entretien.
  Future<List<AmbulanceDetail>> details({
    String texte = '',
    StatutAmbulance? statut,
    TypeAmbulance? type,
  }) async {
    final Database db = await _db;
    final List<String> conditions = [];
    final List<Object?> args = [];
    final String t = texte.trim();
    if (t.isNotEmpty) {
      conditions.add('a.immatriculation LIKE ?');
      args.add('%$t%');
    }
    if (statut != null) {
      conditions.add('a.statut = ?');
      args.add(statut.code);
    }
    if (type != null) {
      conditions.add('a.type = ?');
      args.add(type.code);
    }
    final String where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT a.*,
        (SELECT COUNT(*) FROM ambulanciers e WHERE e.ambulance_id = a.id) AS nb_equipiers,
        (SELECT COUNT(*) FROM ambulanciers e
           WHERE e.ambulance_id = a.id AND e.disponible = 1) AS nb_dispo,
        (SELECT COUNT(*) FROM interventions i
           WHERE i.ambulance_id = a.id AND i.statut = 'terminee') AS nb_missions,
        (SELECT COUNT(*) FROM maintenances m
           WHERE m.ambulance_id = a.id AND m.statut = 'en_cours') AS nb_maint,
        (SELECT m.prochain_entretien_km FROM maintenances m
           WHERE m.ambulance_id = a.id AND m.statut = 'terminee'
             AND m.prochain_entretien_km IS NOT NULL
           ORDER BY m.date DESC, m.id DESC LIMIT 1) AS seuil_km
      FROM ambulances a
      $where
      ORDER BY a.immatriculation
    ''', args);

    final List<AmbulanceDetail> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(AmbulanceDetail(
        ambulance: Ambulance.fromMap(r),
        nbEquipiers: (r['nb_equipiers'] as int?) ?? 0,
        nbEquipiersDisponibles: (r['nb_dispo'] as int?) ?? 0,
        nbMissions: (r['nb_missions'] as int?) ?? 0,
        nbMaintenancesEnCours: (r['nb_maint'] as int?) ?? 0,
        seuilEntretienKm: r['seuil_km'] as int?,
      ));
    }
    return res;
  }

  Future<AmbulanceDetail?> detailParId(int id) async {
    final List<AmbulanceDetail> tous = await details();
    for (final AmbulanceDetail d in tous) {
      if (d.ambulance.id == id) {
        return d;
      }
    }
    return null;
  }

  Future<Ambulance?> parId(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    final List<Map<String, Object?>> rows =
        await e.query('ambulances', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Ambulance.fromMap(rows.first);
  }

  Future<bool> immatriculationExiste(String immatriculation, {int? exclureId}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'ambulances',
      columns: ['id'],
      where: 'UPPER(immatriculation) = ? AND id != ?',
      whereArgs: [immatriculation.trim().toUpperCase(), exclureId ?? -1],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> inserer(Ambulance a) async {
    final Database db = await _db;
    return db.insert('ambulances', a.toMap());
  }

  Future<void> modifier(Ambulance a, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('ambulances', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  }

  /// Supprime l'ambulance et désaffecte son équipage (la table partagée
  /// `ambulanciers` n'a pas de clé étrangère vers `ambulances`).
  Future<void> supprimer(int id) async {
    final Database db = await _db;
    await db.transaction((Transaction txn) async {
      await txn.update(
        'ambulanciers',
        {'ambulance_id': null},
        where: 'ambulance_id = ?',
        whereArgs: [id],
      );
      await txn.delete('ambulances', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> changerStatut(
    int id,
    StatutAmbulance statut, {
    DatabaseExecutor? exec,
  }) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update(
      'ambulances',
      {'statut': statut.code},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deplacer(int id, double lat, double lng) async {
    final Database db = await _db;
    await db.update(
      'ambulances',
      {'latitude': lat, 'longitude': lng},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> ajouterKilometres(int id, int km, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.rawUpdate(
      'UPDATE ambulances SET kilometrage = kilometrage + ? WHERE id = ?',
      [km, id],
    );
  }
}
