import 'package:sqflite/sqflite.dart';

import '../domain/models/intervention.dart';
import '../domain/suivi_cardiaque.dart';
import '../domain/surveillance_cardiaque.dart';
import 'ambulance_schema.dart';

/// Synchronisation du rythme cardiaque entre les espaces :
/// - le téléphone du patient (montre Mibro C2) enregistre chaque mesure ;
/// - le médecin, la régulation et l'ambulancier lisent ces mesures
///   et les seuils du patient (fixés par le médecin).
class RythmeRepository {
  Future<Database> get _db => AmbulanceSchema.database;

  static const String _table = 'mesures_cardiaques';

  /// Enregistre les mesures d'un patient. La montre renvoie toute la journée
  /// à chaque lecture : les mesures déjà connues (même date) sont ignorées.
  Future<void> enregistrer(int patientId, List<MesureCardiaque> mesures) async {
    if (mesures.isEmpty) {
      return;
    }
    final Database db = await _db;
    final Batch batch = db.batch();
    for (final MesureCardiaque m in mesures) {
      batch.insert(
        _table,
        {
          'patient_id': patientId,
          'bpm': m.bpm,
          'date': m.date.toIso8601String(),
          'source': m.simulee ? 'Simulation' : m.source,
          'simulee': m.simulee ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Mesures du patient sur la [periode], de la plus ancienne à la plus récente.
  Future<List<MesureCardiaque>> historique(
    int patientId, {
    Duration periode = const Duration(hours: 3),
  }) async {
    final Database db = await _db;
    final String depuis = DateTime.now().subtract(periode).toIso8601String();
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'patient_id = ? AND date >= ?',
      whereArgs: [patientId, depuis],
      orderBy: 'date',
    );
    final List<MesureCardiaque> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(_mesure(r));
    }
    return res;
  }

  /// Seuils du patient (45–120 bpm si le médecin n'en a pas fixé).
  Future<SeuilsCardiaques> seuils(int patientId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'seuils_cardiaques',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const SeuilsCardiaques();
    }
    return SeuilsCardiaques(
      min: (rows.first['min'] as int?) ?? 45,
      max: (rows.first['max'] as int?) ?? 120,
    );
  }

  Future<void> enregistrerSeuils(int patientId, SeuilsCardiaques s) async {
    final Database db = await _db;
    await db.insert(
      'seuils_cardiaques',
      {
        'patient_id': patientId,
        'min': s.min,
        'max': s.max,
        'modifie_le': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Tableau de suivi : un résumé par patient (dernière mesure, seuils,
  /// intervention en cours). [medecinId] : seulement les patients de ce médecin.
  Future<List<SuiviPatient>> suivi({int? medecinId, int? patientId}) async {
    final Database db = await _db;
    final DateTime maintenant = DateTime.now();
    final String debutJour =
        DateTime(maintenant.year, maintenant.month, maintenant.day).toIso8601String();
    final List<String> ouvertes = [];
    for (final StatutIntervention s in StatutIntervention.values) {
      if (s.estOuverte) {
        ouvertes.add("'${s.code}'");
      }
    }
    final List<String> conditions = [];
    final List<Object?> args = [debutJour];
    if (medecinId != null) {
      conditions.add('p.medecin_id = ?');
      args.add(medecinId);
    }
    if (patientId != null) {
      conditions.add('p.id = ?');
      args.add(patientId);
    }
    final String where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT p.id, p.nom, p.prenom, p.medecin_id,
             m.bpm, m.date, m.source, m.simulee,
             s.min AS seuil_min, s.max AS seuil_max,
             (SELECT COUNT(*) FROM $_table j
               WHERE j.patient_id = p.id AND j.date >= ?) AS nb_jour,
             (SELECT i.id FROM interventions i
               WHERE i.patient_id = p.id AND i.statut IN (${ouvertes.join(', ')})
               ORDER BY i.id DESC LIMIT 1) AS intervention_id
      FROM patients p
      LEFT JOIN $_table m ON m.id = (
        SELECT d.id FROM $_table d WHERE d.patient_id = p.id
        ORDER BY d.date DESC LIMIT 1)
      LEFT JOIN seuils_cardiaques s ON s.patient_id = p.id
      $where
    ''', args);

    final List<SuiviPatient> res = [];
    for (final Map<String, Object?> r in rows) {
      final int? min = r['seuil_min'] as int?;
      final int? max = r['seuil_max'] as int?;
      res.add(SuiviPatient(
        patientId: r['id'] as int,
        nom: '${r['prenom'] ?? ''} ${r['nom'] ?? ''}'.trim(),
        medecinId: r['medecin_id'] as int?,
        derniere: r['bpm'] == null ? null : _mesure(r),
        seuils: (min != null && max != null)
            ? SeuilsCardiaques(min: min, max: max)
            : const SeuilsCardiaques(),
        mesuresAujourdhui: (r['nb_jour'] as int?) ?? 0,
        interventionId: r['intervention_id'] as int?,
      ));
    }
    return SuiviPatient.trier(res, maintenant: maintenant);
  }

  /// Résumé d'un seul patient (carte « Rythme du patient » d'une mission).
  Future<SuiviPatient?> resume(int patientId) async {
    final List<SuiviPatient> l = await suivi(patientId: patientId);
    return l.isEmpty ? null : l.first;
  }

  static MesureCardiaque _mesure(Map<String, Object?> r) {
    return MesureCardiaque(
      bpm: r['bpm'] as int,
      date: DateTime.parse(r['date'] as String),
      source: (r['source'] as String?) ?? '',
      simulee: r['simulee'] == 1,
    );
  }
}
