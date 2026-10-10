import 'package:sqflite/sqflite.dart';

import '../../../models/patient.dart';
import 'ambulance_schema.dart';

/// Lecture seule des patients (table gérée par le module 1)
/// pour rattacher une intervention à un patient.
class PatientLookup {
  Future<Database> get _db => AmbulanceSchema.database;

  Future<List<Patient>> lister() async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('patients', orderBy: 'nom COLLATE NOCASE, prenom COLLATE NOCASE');
    final List<Patient> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Patient.fromMap(r));
    }
    return res;
  }

  Future<Patient?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('patients', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Patient.fromMap(rows.first);
  }
}
