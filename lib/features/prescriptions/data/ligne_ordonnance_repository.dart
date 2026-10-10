import 'package:sqflite/sqflite.dart';

import '../domain/models/ligne_ordonnance.dart';
import '../domain/models/ordonnance.dart';
import '../domain/models/vues_traitement.dart';
import 'prescriptions_schema.dart';

class LigneOrdonnanceRepository {
  Future<Database> get _db => PrescriptionsSchema.database;

  Future<List<LigneOrdonnance>> parOrdonnance(int ordonnanceId, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    final List<Map<String, Object?>> rows = await e.query(
      'ligne_ordonnance',
      where: 'ordonnance_id = ?',
      whereArgs: [ordonnanceId],
      orderBy: 'id',
    );
    final List<LigneOrdonnance> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(LigneOrdonnance.fromMap(r));
    }
    return res;
  }

  Future<LigneOrdonnance?> parId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('ligne_ordonnance', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : LigneOrdonnance.fromMap(rows.first);
  }

  /// Médicaments délivrés au patient dont le traitement est en cours
  /// (stock restant, fin de stock, renouvellement).
  Future<List<StockTraitement>> stocks(int patientId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT l.*,
        o.numero AS o_numero, o.patient_id AS o_patient_id, o.medecin_id AS o_medecin_id,
        o.consultation_id AS o_consultation_id, o.date_emission AS o_date_emission,
        o.date_expiration AS o_date_expiration, o.statut AS o_statut,
        o.nb_renouvellements AS o_nb_renouvellements,
        o.ordonnance_origine_id AS o_ordonnance_origine_id,
        o.hash_signature AS o_hash_signature, o.motif_annulation AS o_motif_annulation,
        m.nom_commercial, m.dosage, m.forme, m.unites_par_boite,
        (SELECT COUNT(*) FROM prise p WHERE p.ligne_id = l.id AND p.statut = 'prise') AS prises_faites,
        (SELECT COUNT(*) FROM prise p WHERE p.ligne_id = l.id AND p.statut = 'prevue') AS prises_restantes
      FROM ligne_ordonnance l
      JOIN ordonnance o ON o.id = l.ordonnance_id
      JOIN medicament m ON m.id = l.medicament_id
      WHERE o.patient_id = ?
        AND o.statut IN ('partiellement_delivree', 'delivree', 'expiree')
        AND l.quantite_delivree > 0
      ORDER BY o.date_emission DESC
    ''', [patientId]);

    final List<StockTraitement> res = [];
    for (final Map<String, Object?> r in rows) {
      // Traitement terminé : plus aucune prise prévue.
      if (((r['prises_restantes'] as int?) ?? 0) == 0) {
        continue;
      }
      res.add(StockTraitement(
        ordonnance: Ordonnance.fromMap({
          'id': r['ordonnance_id'],
          'numero': r['o_numero'],
          'patient_id': r['o_patient_id'],
          'medecin_id': r['o_medecin_id'],
          'consultation_id': r['o_consultation_id'],
          'date_emission': r['o_date_emission'],
          'date_expiration': r['o_date_expiration'],
          'statut': r['o_statut'],
          'nb_renouvellements': r['o_nb_renouvellements'],
          'ordonnance_origine_id': r['o_ordonnance_origine_id'],
          'hash_signature': r['o_hash_signature'],
          'motif_annulation': r['o_motif_annulation'],
        }),
        ligne: LigneOrdonnance.fromMap(r),
        medicament: '${r['nom_commercial']} ${r['dosage']}',
        forme: r['forme'] as String,
        unitesParBoite: r['unites_par_boite'] as int,
        prisesFaites: (r['prises_faites'] as int?) ?? 0,
      ));
    }
    return res;
  }

  /// Contrôle « Cette DCI figure déjà dans l'ordonnance ».
  Future<bool> dciPresente(int ordonnanceId, String dci, {int? exclureLigneId}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT l.id FROM ligne_ordonnance l
      JOIN medicament m ON m.id = l.medicament_id
      WHERE l.ordonnance_id = ? AND m.dci = ? COLLATE NOCASE AND l.id != ?
      LIMIT 1
    ''', [ordonnanceId, dci, exclureLigneId ?? -1]);
    return rows.isNotEmpty;
  }

  Future<int> inserer(LigneOrdonnance l, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('ligne_ordonnance', l.toMap());
  }

  /// Brouillon uniquement (déclencheur trg_ligne_verrou).
  Future<void> modifier(LigneOrdonnance l, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('ligne_ordonnance', l.toMap(), where: 'id = ?', whereArgs: [l.id]);
  }

  /// Délivrance : seule colonne modifiable après validation.
  Future<void> enregistrerDelivrance(int id, int quantiteDelivree, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update(
      'ligne_ordonnance',
      {'quantite_delivree': quantiteDelivree},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Brouillon uniquement (déclencheur trg_ligne_suppression_verrou).
  Future<void> supprimer(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('ligne_ordonnance', where: 'id = ?', whereArgs: [id]);
  }
}
