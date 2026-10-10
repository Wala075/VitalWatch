import 'package:sqflite/sqflite.dart';

import '../domain/dates_sql.dart';
import '../domain/models/prise.dart';
import '../domain/models/vues_traitement.dart';
import 'prescriptions_schema.dart';

class PriseRepository {
  Future<Database> get _db => PrescriptionsSchema.database;

  /// Planning généré à la validation (PlanningPrises.generer).
  Future<void> insererToutes(List<Prise> prises, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    final Batch b = e.batch();
    for (final Prise p in prises) {
      b.insert('prise', p.toMap());
    }
    await b.commit(noResult: true);
  }

  Future<List<Prise>> parLigne(int ligneId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'prise',
      where: 'ligne_id = ?',
      whereArgs: [ligneId],
      orderBy: 'heure_prevue',
    );
    return _liste(rows);
  }

  /// Prises d'un patient entre deux instants (planning du jour, calendrier).
  /// Les ordonnances annulées et les brouillons sont exclus.
  Future<List<Prise>> parPatient(int patientId, DateTime du, DateTime au) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT p.* FROM prise p
      JOIN ligne_ordonnance l ON l.id = p.ligne_id
      JOIN ordonnance o ON o.id = l.ordonnance_id
      WHERE o.patient_id = ?
        AND o.statut NOT IN ('brouillon', 'annulee')
        AND p.heure_prevue BETWEEN ? AND ?
      ORDER BY p.heure_prevue
    ''', [patientId, DatesSql.dateHeure(du), DatesSql.dateHeure(au)]);
    return _liste(rows);
  }

  /// Planning d'un patient entre deux instants, avec les médicaments.
  /// Ordonnances validées ou délivrées seulement (pas les brouillons ni les annulées).
  Future<List<PrisePlanifiee>> planning(int patientId, DateTime du, DateTime au) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT p.*, l.dose_par_prise, l.instructions, o.numero,
        m.nom_commercial, m.dosage, m.forme
      FROM prise p
      JOIN ligne_ordonnance l ON l.id = p.ligne_id
      JOIN ordonnance o ON o.id = l.ordonnance_id
      JOIN medicament m ON m.id = l.medicament_id
      WHERE o.patient_id = ?
        AND o.statut NOT IN ('brouillon', 'annulee')
        AND p.heure_prevue BETWEEN ? AND ?
      ORDER BY p.heure_prevue, m.nom_commercial
    ''', [patientId, DatesSql.dateHeure(du), DatesSql.dateHeure(au)]);

    final List<PrisePlanifiee> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(PrisePlanifiee(
        prise: Prise.fromMap(r),
        medicament: '${r['nom_commercial']} ${r['dosage']}',
        forme: r['forme'] as String,
        dose: (r['dose_par_prise'] as num).toDouble(),
        numero: r['numero'] as String,
        instructions: r['instructions'] as String?,
      ));
    }
    return res;
  }

  /// Observance jour par jour sur [jours] jours (prises échues seulement).
  Future<List<ObservanceJour>> observanceParJour(int patientId, {int jours = 7}) async {
    final Database db = await _db;
    final DateTime maintenant = DateTime.now();
    final DateTime debut = DatesSql.jour(maintenant).subtract(Duration(days: jours - 1));
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT date(p.heure_prevue) AS jour,
        SUM(CASE WHEN p.statut = 'prise' THEN 1 ELSE 0 END) AS faites,
        COUNT(*) AS echues
      FROM prise p
      JOIN ligne_ordonnance l ON l.id = p.ligne_id
      JOIN ordonnance o ON o.id = l.ordonnance_id
      WHERE o.patient_id = ?
        AND o.statut NOT IN ('brouillon', 'annulee')
        AND p.heure_prevue BETWEEN ? AND ?
      GROUP BY date(p.heure_prevue)
    ''', [patientId, DatesSql.dateHeure(debut), DatesSql.dateHeure(maintenant)]);

    final Map<String, Map<String, Object?>> parJour = {};
    for (final Map<String, Object?> r in rows) {
      parJour[r['jour'] as String] = r;
    }
    final List<ObservanceJour> res = [];
    for (int i = 0; i < jours; i++) {
      final DateTime jour = debut.add(Duration(days: i));
      final Map<String, Object?>? r = parJour[DatesSql.date(jour)];
      res.add(ObservanceJour(
        jour: jour,
        faites: r == null ? 0 : (r['faites'] as int? ?? 0),
        echues: r == null ? 0 : (r['echues'] as int? ?? 0),
      ));
    }
    return res;
  }

  /// Cocher « prise » ou « oubliée ».
  Future<void> marquer(int id, StatutPrise statut, {DateTime? heureReelle}) async {
    final Database db = await _db;
    await db.update(
      'prise',
      {
        'statut': statut.valeur,
        'heure_reelle': heureReelle == null ? null : DatesSql.dateHeure(heureReelle),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Prises encore « prévues » avant [limite] → « oubliée ».
  Future<int> marquerOubliees(DateTime limite) async {
    final Database db = await _db;
    return db.update(
      'prise',
      {'statut': StatutPrise.oubliee.valeur},
      where: 'statut = ? AND heure_prevue < ?',
      whereArgs: [StatutPrise.prevue.valeur, DatesSql.dateHeure(limite)],
    );
  }

  /// Prises faites d'une ligne (calcul du stock restant).
  Future<int> nombrePrises(int ligneId) async {
    final Database db = await _db;
    return Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM prise WHERE ligne_id = ? AND statut = 'prise'",
          [ligneId],
        )) ??
        0;
  }

  /// Observance en % = prises faites ÷ prises échues sur [jours] jours glissants.
  /// null si aucune prise n'était prévue sur la période.
  Future<double?> observance(int patientId, {int jours = 7}) async {
    final Database db = await _db;
    final DateTime maintenant = DateTime.now();
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT ROUND(100.0 * SUM(CASE WHEN p.statut = 'prise' THEN 1 ELSE 0 END) / COUNT(*), 1)
             AS observance
      FROM prise p
      JOIN ligne_ordonnance l ON l.id = p.ligne_id
      JOIN ordonnance o ON o.id = l.ordonnance_id
      WHERE o.patient_id = ?
        AND o.statut NOT IN ('brouillon', 'annulee')
        AND p.heure_prevue BETWEEN ? AND ?
    ''', [
      patientId,
      DatesSql.dateHeure(maintenant.subtract(Duration(days: jours))),
      DatesSql.dateHeure(maintenant),
    ]);
    return (rows.first['observance'] as num?)?.toDouble();
  }

  List<Prise> _liste(List<Map<String, Object?>> rows) {
    final List<Prise> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Prise.fromMap(r));
    }
    return res;
  }
}
