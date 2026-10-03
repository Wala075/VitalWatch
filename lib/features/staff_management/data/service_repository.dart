import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../../../models/service.dart';
import '../domain/staff_models.dart';

class ServiceRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<List<Service>> lister() async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('services', orderBy: 'nom COLLATE NOCASE');
    final List<Service> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Service.fromMap(r));
    }
    return res;
  }

  Future<Service?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('services', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Service.fromMap(rows.first);
  }

  /// Services + nombre de médecins / patients + chef (stats par service).
  Future<List<ServiceStats>> statistiques({String texte = ''}) async {
    final Database db = await _db;
    final String t = texte.trim();
    final String where = t.isEmpty ? '' : 'WHERE s.nom LIKE ?';
    final List<Object?> args = t.isEmpty ? [] : ['%$t%'];

    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT s.*,
        c.prenom AS chef_prenom,
        c.nom AS chef_nom,
        (SELECT COUNT(*) FROM medecins m WHERE m.service_id = s.id) AS nb_medecins,
        (SELECT COUNT(*) FROM medecins m WHERE m.service_id = s.id AND m.disponible = 1) AS nb_dispo,
        (SELECT COUNT(*) FROM patients p WHERE p.service_id = s.id) AS nb_patients
      FROM services s
      LEFT JOIN medecins c ON c.id = s.chef_service_id
      $where
      ORDER BY s.nom COLLATE NOCASE
    ''', args);

    final List<ServiceStats> res = [];
    for (final Map<String, Object?> r in rows) {
      final Object? chefNom = r['chef_nom'];
      res.add(ServiceStats(
        service: Service.fromMap(r),
        chefNom: chefNom == null ? null : 'Dr ${r['chef_prenom']} $chefNom',
        nbMedecins: (r['nb_medecins'] as int?) ?? 0,
        nbMedecinsDisponibles: (r['nb_dispo'] as int?) ?? 0,
        nbPatients: (r['nb_patients'] as int?) ?? 0,
      ));
    }
    return res;
  }

  Future<bool> nomExiste(String nom, {int? exclureId}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'services',
      columns: ['id'],
      where: 'nom = ? COLLATE NOCASE AND id != ?',
      whereArgs: [nom.trim(), exclureId ?? -1],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> inserer(Service s) async {
    final Database db = await _db;
    return db.insert('services', s.toMap());
  }

  Future<void> modifier(Service s) async {
    final Database db = await _db;
    await db.update('services', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> supprimer(int id) async {
    final Database db = await _db;
    await db.delete('services', where: 'id = ?', whereArgs: [id]);
  }

  /// Retire le médecin de la fonction de chef (changement de service, suppression).
  Future<void> retirerChef(int medecinId, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update(
      'services',
      {'chef_service_id': null},
      where: 'chef_service_id = ?',
      whereArgs: [medecinId],
    );
  }
}
