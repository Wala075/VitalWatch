import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../../../models/medecin.dart';
import '../domain/conges.dart';
import '../domain/staff_models.dart';

class MedecinRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  /// Recherche multicritère : texte (nom, prénom, matricule, spécialité, email),
  /// service et disponibilité.
  Future<List<MedecinDetail>> rechercher(MedecinFiltre f) async {
    final Database db = await _db;
    final List<String> conditions = [];
    final List<Object?> args = [];

    final String t = f.texte.trim();
    if (t.isNotEmpty) {
      conditions.add('(m.nom LIKE ? OR m.prenom LIKE ? OR m.matricule LIKE ? '
          'OR m.specialite LIKE ? OR m.email LIKE ?)');
      for (int i = 0; i < 5; i++) {
        args.add('%$t%');
      }
    }
    final int? serviceId = f.serviceId;
    if (serviceId != null) {
      conditions.add('m.service_id = ?');
      args.add(serviceId);
    }
    final bool? disponible = f.disponible;
    if (disponible != null) {
      conditions.add('m.disponible = ?');
      args.add(disponible ? 1 : 0);
    }
    final String where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT m.*,
        s.nom AS service_nom,
        (SELECT COUNT(*) FROM patients p WHERE p.medecin_id = m.id) AS nb_patients
      FROM medecins m
      LEFT JOIN services s ON s.id = m.service_id
      $where
      ORDER BY m.nom COLLATE NOCASE, m.prenom COLLATE NOCASE
    ''', args);

    final List<MedecinDetail> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(MedecinDetail(
        medecin: Medecin.fromMap(r),
        serviceNom: r['service_nom'] as String?,
        nbPatients: (r['nb_patients'] as int?) ?? 0,
      ));
    }
    return res;
  }

  Future<Medecin?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('medecins', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Medecin.fromMap(rows.first);
  }

  Future<bool> matriculeExiste(String matricule, {int? exclureId}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'medecins',
      columns: ['id'],
      where: 'matricule = ? COLLATE NOCASE AND id != ?',
      whereArgs: [matricule.trim(), exclureId ?? -1],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Médecin disponible du service ayant le moins de patients, et sans
  /// congé validé sur la période [du]–[au] (aujourd'hui par défaut).
  Future<int?> moinsCharge(
    int serviceId, {
    int? exclureId,
    DateTime? du,
    DateTime? au,
  }) async {
    final Database db = await _db;
    final DateTime debut = du ?? DateTime.now();
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT m.id, COUNT(p.id) AS charge
      FROM medecins m
      LEFT JOIN patients p ON p.medecin_id = m.id
      WHERE m.service_id = ? AND m.disponible = 1 AND m.id != ?
        AND NOT EXISTS (
          SELECT 1 FROM conges c
          WHERE c.demandeur_role = 'medecin' AND c.demandeur_id = m.id
            AND c.statut = 'validee'
            AND c.date_debut <= ? AND c.date_fin >= ?
        )
      GROUP BY m.id
      ORDER BY charge ASC, m.id ASC
      LIMIT 1
    ''', [
      serviceId,
      exclureId ?? -1,
      RegleConges.iso(au ?? debut),
      RegleConges.iso(debut),
    ]);
    return rows.isEmpty ? null : rows.first['id'] as int?;
  }

  /// Congé (false) / retour (true).
  Future<void> changerDisponibilite(int id, bool disponible) async {
    final Database db = await _db;
    await db.update(
      'medecins',
      {'disponible': disponible ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> inserer(Medecin m, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('medecins', m.toMap());
  }

  Future<void> modifier(Medecin m, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('medecins', m.toMap(), where: 'id = ?', whereArgs: [m.id]);
  }

  Future<void> supprimer(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('medecins', where: 'id = ?', whereArgs: [id]);
  }
}
