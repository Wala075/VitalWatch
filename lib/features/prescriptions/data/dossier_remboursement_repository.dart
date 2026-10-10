import 'package:sqflite/sqflite.dart';

import '../domain/dates_sql.dart';
import '../domain/models/dossier_remboursement.dart';
import '../domain/models/vues_remboursement.dart';
import 'numerotation.dart';
import 'prescriptions_schema.dart';

class DossierRemboursementRepository {
  Future<Database> get _db => PrescriptionsSchema.database;

  /// Suivi par statut, éventuellement pour un seul patient.
  Future<List<DossierRemboursement>> lister({int? patientId, StatutDossier? statut}) async {
    final Database db = await _db;
    final List<String> conditions = [];
    final List<Object?> args = [];
    if (patientId != null) {
      conditions.add('o.patient_id = ?');
      args.add(patientId);
    }
    if (statut != null) {
      conditions.add('d.statut = ?');
      args.add(statut.valeur);
    }
    final String where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT d.* FROM dossier_remboursement d
      JOIN ordonnance o ON o.id = d.ordonnance_id
      $where
      ORDER BY d.id DESC
    ''', args);
    return _liste(rows);
  }

  static const String _selectResume = '''
    SELECT d.*, o.numero AS o_numero, o.patient_id AS o_patient_id,
      o.date_emission AS o_date_emission,
      p.prenom AS p_prenom, p.nom AS p_nom,
      a.nom AS a_nom, a.delai_reponse_jours AS a_delai
    FROM dossier_remboursement d
    JOIN ordonnance o ON o.id = d.ordonnance_id
    LEFT JOIN patients p ON p.id = o.patient_id
    LEFT JOIN contrat_assurance c ON c.id = d.contrat_id
    LEFT JOIN assurance a ON a.id = c.assurance_id
  ''';

  /// Dossiers avec numéro d'ordonnance, patient et assurance.
  Future<List<DossierResume>> listerResumes({int? patientId, StatutDossier? statut}) async {
    final Database db = await _db;
    final List<String> conditions = [];
    final List<Object?> args = [];
    if (patientId != null) {
      conditions.add('o.patient_id = ?');
      args.add(patientId);
    }
    if (statut != null) {
      conditions.add('d.statut = ?');
      args.add(statut.valeur);
    }
    final String where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final List<Map<String, Object?>> rows =
        await db.rawQuery('$_selectResume $where ORDER BY d.id DESC', args);
    final List<DossierResume> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(_resume(r));
    }
    return res;
  }

  Future<DossierResume?> resume(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('$_selectResume WHERE d.id = ?', [id]);
    return rows.isEmpty ? null : _resume(rows.first);
  }

  DossierResume _resume(Map<String, Object?> r) {
    final Object? pNom = r['p_nom'];
    return DossierResume(
      dossier: DossierRemboursement.fromMap(r),
      ordonnanceNumero: r['o_numero'] as String,
      dateOrdonnance: DatesSql.lire(r['o_date_emission']),
      patientId: r['o_patient_id'] as int,
      patientNom: pNom == null ? 'Patient supprimé' : '${r['p_prenom']} $pNom',
      assuranceNom: (r['a_nom'] as String?) ?? 'CNAM',
      delaiReponseJours: (r['a_delai'] as int?) ?? 30,
    );
  }

  Future<DossierRemboursement?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('dossier_remboursement', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : DossierRemboursement.fromMap(rows.first);
  }

  Future<List<DossierRemboursement>> parOrdonnance(int ordonnanceId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'dossier_remboursement',
      where: 'ordonnance_id = ?',
      whereArgs: [ordonnanceId],
      orderBy: 'id DESC',
    );
    return _liste(rows);
  }

  Future<String> prochainNumero(int annee, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return Numerotation.prochain(e, table: 'dossier_remboursement', prefixe: 'REM', annee: annee);
  }

  Future<int> inserer(DossierRemboursement d, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('dossier_remboursement', d.toMap());
  }

  /// Changement de statut, montants, dates, motif de refus, paiement.
  Future<void> modifier(DossierRemboursement d, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('dossier_remboursement', d.toMap(), where: 'id = ?', whereArgs: [d.id]);
  }

  /// Brouillon uniquement (contrôlé par le métier).
  Future<void> supprimer(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('dossier_remboursement', where: 'id = ?', whereArgs: [id]);
  }

  /// Métier 10 : plafond consommé sur l'année civile, recalculé à chaque
  /// affichage (jamais stocké, donc jamais désynchronisé).
  Future<double> plafondConsomme(int contratId, {int? annee}) async {
    final Database db = await _db;
    final int a = annee ?? DateTime.now().year;
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT COALESCE(SUM(part_obligatoire), 0) AS consomme
      FROM dossier_remboursement
      WHERE contrat_id = ?
        AND statut IN ('accepte', 'partiel', 'rembourse')
        AND strftime('%Y', date_reponse) = ?
    ''', [contratId, a.toString()]);
    return (rows.first['consomme'] as num).toDouble();
  }

  /// Dossiers en cours depuis plus de [jours] jours (relance automatique).
  Future<List<DossierRemboursement>> enRetard(int jours) async {
    final Database db = await _db;
    final DateTime limite = DateTime.now().subtract(Duration(days: jours));
    final List<Map<String, Object?>> rows = await db.query(
      'dossier_remboursement',
      where: "statut IN ('soumis', 'en_cours') AND date_depot < ?",
      whereArgs: [DatesSql.dateHeure(limite)],
    );
    return _liste(rows);
  }

  List<DossierRemboursement> _liste(List<Map<String, Object?>> rows) {
    final List<DossierRemboursement> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(DossierRemboursement.fromMap(r));
    }
    return res;
  }
}
