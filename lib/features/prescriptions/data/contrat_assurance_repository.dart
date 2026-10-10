import 'package:sqflite/sqflite.dart';

import '../domain/dates_sql.dart';
import '../domain/models/contrat_assurance.dart';
import 'prescriptions_schema.dart';

class ContratAssuranceRepository {
  Future<Database> get _db => PrescriptionsSchema.database;

  /// Contrat actif à une date : date_debut ≤ date ≤ date_fin (ou pas de date_fin).
  static const String _actif = 'c.date_debut <= ? AND (c.date_fin IS NULL OR c.date_fin >= ?)';

  /// Tous les contrats du patient, actifs puis expirés.
  Future<List<ContratAssurance>> parPatient(int patientId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'contrat_assurance',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'date_fin IS NOT NULL, date_debut DESC',
    );
    return _liste(rows);
  }

  Future<ContratAssurance?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('contrat_assurance', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : ContratAssurance.fromMap(rows.first);
  }

  /// Contrats actifs du patient à [date] (éligibilité, calcul de prise en charge).
  Future<List<ContratAssurance>> actifsLe(int patientId, DateTime date) async {
    final Database db = await _db;
    final String jour = DatesSql.date(date);
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT c.* FROM contrat_assurance c
      WHERE c.patient_id = ? AND $_actif
      ORDER BY c.date_debut
    ''', [patientId, jour, jour]);
    return _liste(rows);
  }

  /// Contrôle « Un seul contrat CNAM actif par patient ».
  Future<bool> aUnContratCnamActif(int patientId, DateTime date, {int? exclureId}) async {
    final Database db = await _db;
    final String jour = DatesSql.date(date);
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT c.id FROM contrat_assurance c
      JOIN assurance a ON a.id = c.assurance_id
      WHERE c.patient_id = ? AND a.type = 'cnam' AND c.id != ? AND $_actif
      LIMIT 1
    ''', [patientId, exclureId ?? -1, jour, jour]);
    return rows.isNotEmpty;
  }

  Future<bool> numeroExiste(
    int assuranceId,
    String numeroAdherent,
    Beneficiaire beneficiaire, {
    int? exclureId,
  }) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'contrat_assurance',
      columns: ['id'],
      where: 'assurance_id = ? AND numero_adherent = ? AND beneficiaire = ? AND id != ?',
      whereArgs: [assuranceId, numeroAdherent.trim(), beneficiaire.valeur, exclureId ?? -1],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> inserer(ContratAssurance c, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('contrat_assurance', c.toMap());
  }

  Future<void> modifier(ContratAssurance c, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('contrat_assurance', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  /// APCI déclarée par le médecin (code null : APCI retirée).
  Future<void> modifierApci(int id, String? codeApci, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update(
      'contrat_assurance',
      {'apci': codeApci == null ? 0 : 1, 'code_apci': codeApci},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Résiliation (date_fin) au lieu de suppression.
  Future<void> resilier(int id, DateTime dateFin, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update(
      'contrat_assurance',
      {'date_fin': DatesSql.date(dateFin)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  List<ContratAssurance> _liste(List<Map<String, Object?>> rows) {
    final List<ContratAssurance> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(ContratAssurance.fromMap(r));
    }
    return res;
  }
}
