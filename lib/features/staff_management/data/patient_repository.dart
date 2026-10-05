import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../../../models/patient.dart';
import '../domain/staff_models.dart';

class PatientRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  /// Recherche multicritère : texte (nom, prénom, CIN, téléphone), service,
  /// groupe sanguin, sexe, patients non affectés.
  Future<List<PatientDetail>> rechercher(PatientFiltre f) async {
    final Database db = await _db;
    final List<String> conditions = [];
    final List<Object?> args = [];

    final String t = f.texte.trim();
    if (t.isNotEmpty) {
      conditions.add('(p.nom LIKE ? OR p.prenom LIKE ? OR p.cin LIKE ? '
          'OR p.telephone LIKE ?)');
      for (int i = 0; i < 4; i++) {
        args.add('%$t%');
      }
    }
    final int? serviceId = f.serviceId;
    if (serviceId != null) {
      conditions.add('p.service_id = ?');
      args.add(serviceId);
    }
    final String? groupe = f.groupeSanguin;
    if (groupe != null) {
      conditions.add('p.groupe_sanguin = ?');
      args.add(groupe);
    }
    final String? sexe = f.sexe;
    if (sexe != null) {
      conditions.add('p.sexe = ?');
      args.add(sexe);
    }
    if (f.nonAffectes) {
      conditions.add('p.medecin_id IS NULL');
    }
    final String where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT p.*,
        s.nom AS service_nom,
        m.prenom AS medecin_prenom,
        m.nom AS medecin_nom
      FROM patients p
      LEFT JOIN services s ON s.id = p.service_id
      LEFT JOIN medecins m ON m.id = p.medecin_id
      $where
      ORDER BY p.nom COLLATE NOCASE, p.prenom COLLATE NOCASE
    ''', args);

    final List<PatientDetail> res = [];
    for (final Map<String, Object?> r in rows) {
      final Object? medecinNom = r['medecin_nom'];
      res.add(PatientDetail(
        patient: Patient.fromMap(r),
        serviceNom: r['service_nom'] as String?,
        medecinNom: medecinNom == null
            ? null
            : 'Dr ${r['medecin_prenom']} $medecinNom',
      ));
    }
    return res;
  }

  Future<Patient?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('patients', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Patient.fromMap(rows.first);
  }

  Future<List<Patient>> parMedecin(int medecinId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db
        .query('patients', where: 'medecin_id = ?', whereArgs: [medecinId]);
    final List<Patient> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Patient.fromMap(r));
    }
    return res;
  }

  Future<bool> cinExiste(String cin, {int? exclureId}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'patients',
      columns: ['id'],
      where: 'cin = ? AND id != ?',
      whereArgs: [cin.trim(), exclureId ?? -1],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Doublon potentiel : même nom + même date de naissance.
  Future<Patient?> doublonNomDate(
    String nom,
    String dateIso, {
    int? exclureId,
  }) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'patients',
      where: 'LOWER(TRIM(nom)) = LOWER(?) AND date_naissance = ? AND id != ?',
      whereArgs: [nom.trim(), dateIso, exclureId ?? -1],
      limit: 1,
    );
    return rows.isEmpty ? null : Patient.fromMap(rows.first);
  }

  Future<int> compterParService(int serviceId, {int? exclureId}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM patients WHERE service_id = ? AND id != ?',
      [serviceId, exclureId ?? -1],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<int> inserer(Patient p, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('patients', p.toMap());
  }

  Future<void> modifier(Patient p, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('patients', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> affecterMedecin(int patientId, int? medecinId) async {
    final Database db = await _db;
    await db.update(
      'patients',
      {'medecin_id': medecinId},
      where: 'id = ?',
      whereArgs: [patientId],
    );
  }

  Future<void> supprimer(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('patients', where: 'id = ?', whereArgs: [id]);
  }
}
