import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../../../models/medecin.dart';
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

  /// Médecin disponible du service ayant le moins de patients.
  Future<int?> moinsCharge(int serviceId, {int? exclureId}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT m.id, COUNT(p.id) AS charge
      FROM medecins m
      LEFT JOIN patients p ON p.medecin_id = m.id
      WHERE m.service_id = ? AND m.disponible = 1 AND m.id != ?
      GROUP BY m.id
      ORDER BY charge ASC, m.id ASC
      LIMIT 1
    ''', [serviceId, exclureId ?? -1]);
    return rows.isEmpty ? null : rows.first['id'] as int?;
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
