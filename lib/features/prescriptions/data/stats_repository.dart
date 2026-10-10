import 'package:sqflite/sqflite.dart';

import '../domain/dates_sql.dart';
import 'prescriptions_schema.dart';

/// Une valeur nommée (barre d'un graphique).
class ValeurStat {
  const ValeurStat(this.libelle, this.valeur);

  final String libelle;
  final double valeur;
}

/// Indicateurs du métier 11.
class Statistiques {
  const Statistiques({
    required this.depensesMensuelles,
    required this.depensesParPatient,
    required this.partCnam,
    required this.partMutuelle,
    required this.partPatient,
    required this.refusParMotif,
    required this.nbRepondus,
    required this.nbRefuses,
    required this.delaiMoyenJours,
    required this.topMedicaments,
    required this.economieGeneriques,
  });

  /// 6 derniers mois, du plus ancien au plus récent (« 2026-05 »).
  final List<ValeurStat> depensesMensuelles;
  final List<ValeurStat> depensesParPatient;
  final double partCnam;
  final double partMutuelle;
  final double partPatient;
  final List<ValeurStat> refusParMotif;
  final int nbRepondus;
  final int nbRefuses;
  final double? delaiMoyenJours;
  final List<ValeurStat> topMedicaments;
  final double economieGeneriques;

  double get tauxRefus => nbRepondus == 0 ? 0 : nbRefuses / nbRepondus;
}

/// Requêtes des statistiques, pour tous ([medecinId] null) ou pour les
/// ordonnances d'un médecin.
class StatsRepository {
  Future<Database> get _db => PrescriptionsSchema.database;

  Future<Statistiques> calculer({int? medecinId}) async {
    final Database db = await _db;
    final String filtre = medecinId == null ? '' : 'AND o.medecin_id = ?';
    final List<Object?> args = medecinId == null ? [] : [medecinId];

    // Dépenses mensuelles (montant des dossiers, par mois de l'ordonnance).
    final DateTime maintenant = DateTime.now();
    final DateTime debut = DateTime(maintenant.year, maintenant.month - 5, 1);
    final List<Map<String, Object?>> mois = await db.rawQuery('''
      SELECT strftime('%Y-%m', o.date_emission) AS mois, SUM(d.montant_total) AS total
      FROM dossier_remboursement d
      JOIN ordonnance o ON o.id = d.ordonnance_id
      WHERE o.date_emission >= ? $filtre
      GROUP BY mois
    ''', [DatesSql.date(debut), ...args]);
    final Map<String, double> parMois = {};
    for (final Map<String, Object?> r in mois) {
      parMois[r['mois'] as String] = (r['total'] as num?)?.toDouble() ?? 0;
    }
    final List<ValeurStat> depensesMensuelles = [];
    for (int i = 0; i < 6; i++) {
      final DateTime m = DateTime(debut.year, debut.month + i, 1);
      final String cle = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      depensesMensuelles.add(ValeurStat(cle, parMois[cle] ?? 0));
    }

    // Dépenses par patient (top 5).
    final List<ValeurStat> parPatient = await _valeurs(db, '''
      SELECT p.prenom || ' ' || p.nom AS libelle, SUM(d.montant_total) AS valeur
      FROM dossier_remboursement d
      JOIN ordonnance o ON o.id = d.ordonnance_id
      JOIN patients p ON p.id = o.patient_id
      WHERE 1 = 1 $filtre
      GROUP BY o.patient_id ORDER BY valeur DESC LIMIT 5
    ''', args);

    // Répartition CNAM / mutuelle / patient (dossiers acceptés).
    final List<Map<String, Object?>> rep = await db.rawQuery('''
      SELECT COALESCE(SUM(d.part_obligatoire), 0) AS cnam,
        COALESCE(SUM(d.part_complementaire), 0) AS mutuelle,
        COALESCE(SUM(d.reste_a_charge), 0) AS patient
      FROM dossier_remboursement d
      JOIN ordonnance o ON o.id = d.ordonnance_id
      WHERE d.statut IN ('accepte', 'partiel', 'rembourse') $filtre
    ''', args);

    // Refus par motif, taux de refus, délai moyen de réponse.
    final List<ValeurStat> refus = await _valeurs(db, '''
      SELECT d.motif_refus AS libelle, COUNT(*) AS valeur
      FROM dossier_remboursement d
      JOIN ordonnance o ON o.id = d.ordonnance_id
      WHERE d.statut = 'refuse' $filtre
      GROUP BY d.motif_refus ORDER BY valeur DESC
    ''', args);
    final List<Map<String, Object?>> reponses = await db.rawQuery('''
      SELECT COUNT(*) AS repondus,
        SUM(CASE WHEN d.statut = 'refuse' THEN 1 ELSE 0 END) AS refuses,
        AVG(julianday(d.date_reponse) - julianday(d.date_depot)) AS delai
      FROM dossier_remboursement d
      JOIN ordonnance o ON o.id = d.ordonnance_id
      WHERE d.date_reponse IS NOT NULL AND d.date_depot IS NOT NULL $filtre
    ''', args);

    // Top 5 des médicaments les plus coûteux (boîtes délivrées × prix public).
    final List<ValeurStat> top = await _valeurs(db, '''
      SELECT m.nom_commercial || ' ' || m.dosage AS libelle,
        SUM(m.prix_public * l.quantite_delivree) AS valeur
      FROM ligne_ordonnance l
      JOIN ordonnance o ON o.id = l.ordonnance_id
      JOIN medicament m ON m.id = l.medicament_id
      WHERE l.quantite_delivree > 0 $filtre
      GROUP BY m.id ORDER BY valeur DESC LIMIT 5
    ''', args);

    // Économie grâce aux génériques : (prix du princeps − prix du générique)
    // × boîtes délivrées.
    final List<Map<String, Object?>> eco = await db.rawQuery('''
      SELECT COALESCE(SUM(((
        SELECT MAX(p.prix_public) FROM medicament p
        WHERE p.generique = 0 AND p.dci = m.dci AND p.dosage = m.dosage AND p.forme = m.forme
      ) - m.prix_public) * l.quantite_delivree), 0) AS economie
      FROM ligne_ordonnance l
      JOIN ordonnance o ON o.id = l.ordonnance_id
      JOIN medicament m ON m.id = l.medicament_id
      WHERE m.generique = 1 AND l.quantite_delivree > 0
        AND EXISTS (SELECT 1 FROM medicament p WHERE p.generique = 0 AND p.dci = m.dci
                    AND p.dosage = m.dosage AND p.forme = m.forme) $filtre
    ''', args);

    final Map<String, Object?> r = rep.first;
    final Map<String, Object?> rp = reponses.first;
    return Statistiques(
      depensesMensuelles: depensesMensuelles,
      depensesParPatient: parPatient,
      partCnam: (r['cnam'] as num).toDouble(),
      partMutuelle: (r['mutuelle'] as num).toDouble(),
      partPatient: (r['patient'] as num).toDouble(),
      refusParMotif: refus,
      nbRepondus: (rp['repondus'] as int?) ?? 0,
      nbRefuses: (rp['refuses'] as int?) ?? 0,
      delaiMoyenJours: (rp['delai'] as num?)?.toDouble(),
      topMedicaments: top,
      economieGeneriques: (eco.first['economie'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<List<ValeurStat>> _valeurs(Database db, String sql, List<Object?> args) async {
    final List<ValeurStat> res = [];
    for (final Map<String, Object?> r in await db.rawQuery(sql, args)) {
      res.add(ValeurStat(
        (r['libelle'] as String?) ?? '—',
        (r['valeur'] as num?)?.toDouble() ?? 0,
      ));
    }
    return res;
  }
}
