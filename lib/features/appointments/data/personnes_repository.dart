import 'package:sqflite/sqflite.dart';

import '../../../models/medecin.dart';
import '../../../models/patient.dart';
import 'rdv_schema.dart';

/// Lecture des médecins et patients saisis dans le module 1
/// (lecture seule : ce module ne les modifie jamais).
class PersonnesRepository {
  Future<List<Medecin>> medecins({bool disponiblesSeulement = false}) async {
    final Database db = await RdvSchema.db;
    final List<Map<String, Object?>> rows = await db.query(
      'medecins',
      where: disponiblesSeulement ? 'disponible = 1' : null,
      orderBy: 'nom COLLATE NOCASE, prenom COLLATE NOCASE',
    );
    return [for (final Map<String, Object?> r in rows) Medecin.fromMap(r)];
  }

  Future<Medecin?> medecin(int id) async {
    final Database db = await RdvSchema.db;
    final List<Map<String, Object?>> rows =
        await db.query('medecins', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Medecin.fromMap(rows.first);
  }

  Future<Patient?> patient(int id) async {
    final Database db = await RdvSchema.db;
    final List<Map<String, Object?>> rows =
        await db.query('patients', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Patient.fromMap(rows.first);
  }

  /// Patients (recherche nom / prénom / CIN). Si [medecinId] est donné :
  /// seulement les patients affectés à ce médecin.
  Future<List<Patient>> patients({String texte = '', int? medecinId}) async {
    final Database db = await RdvSchema.db;
    final String t = texte.trim();
    final List<String> conditions = [];
    final List<Object?> args = [];
    if (t.isNotEmpty) {
      conditions.add('(nom LIKE ? OR prenom LIKE ? OR cin LIKE ?)');
      args.addAll(['%$t%', '%$t%', '%$t%']);
    }
    if (medecinId != null) {
      conditions.add('medecin_id = ?');
      args.add(medecinId);
    }
    final List<Map<String, Object?>> rows = await db.query(
      'patients',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'nom COLLATE NOCASE, prenom COLLATE NOCASE',
    );
    return [for (final Map<String, Object?> r in rows) Patient.fromMap(r)];
  }
}
