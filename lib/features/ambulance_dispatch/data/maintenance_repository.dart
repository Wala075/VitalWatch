import 'package:sqflite/sqflite.dart';

import '../domain/dispatch_models.dart';
import '../domain/models/maintenance.dart';
import 'ambulance_schema.dart';

class MaintenanceRepository {
  Future<Database> get _db => AmbulanceSchema.database;

  Future<List<MaintenanceDetail>> rechercher({
    int? ambulanceId,
    StatutMaintenance? statut,
  }) async {
    final Database db = await _db;
    final List<String> conditions = [];
    final List<Object?> args = [];
    if (ambulanceId != null) {
      conditions.add('m.ambulance_id = ?');
      args.add(ambulanceId);
    }
    if (statut != null) {
      conditions.add('m.statut = ?');
      args.add(statut.code);
    }
    final String where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT m.*, a.immatriculation
      FROM maintenances m
      JOIN ambulances a ON a.id = m.ambulance_id
      $where
      ORDER BY m.date DESC, m.id DESC
    ''', args);

    final List<MaintenanceDetail> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(MaintenanceDetail(
        maintenance: Maintenance.fromMap(r),
        immatriculation: (r['immatriculation'] as String?) ?? '',
      ));
    }
    return res;
  }

  Future<List<Maintenance>> parAmbulance(int ambulanceId, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    final List<Map<String, Object?>> rows = await e.query(
      'maintenances',
      where: 'ambulance_id = ?',
      whereArgs: [ambulanceId],
      orderBy: 'date DESC, id DESC',
    );
    final List<Maintenance> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Maintenance.fromMap(r));
    }
    return res;
  }

  /// Toutes les maintenances d'un statut (contrôle automatique).
  Future<List<Maintenance>> parStatut(
    StatutMaintenance statut, {
    DatabaseExecutor? exec,
  }) async {
    final DatabaseExecutor e = exec ?? await _db;
    final List<Map<String, Object?>> rows = await e.query(
      'maintenances',
      where: 'statut = ?',
      whereArgs: [statut.code],
      orderBy: 'date',
    );
    final List<Maintenance> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Maintenance.fromMap(r));
    }
    return res;
  }

  Future<int> inserer(Maintenance m, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('maintenances', m.toMap());
  }

  Future<void> modifier(Maintenance m, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('maintenances', m.toMap(), where: 'id = ?', whereArgs: [m.id]);
  }

  Future<void> supprimer(int id) async {
    final Database db = await _db;
    await db.delete('maintenances', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> coutTotal({DateTime? depuis}) async {
    final Database db = await _db;
    final String where = depuis == null ? '' : 'AND date >= ?';
    final List<Object?> args = [];
    if (depuis != null) {
      args.add(depuis.toIso8601String().substring(0, 10));
    }
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT SUM(cout) AS total FROM maintenances WHERE statut = 'terminee' $where",
      args,
    );
    final Object? total = rows.first['total'];
    return total is num ? total.toDouble() : 0;
  }
}
