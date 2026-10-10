import 'package:sqflite/sqflite.dart';

import '../domain/dispatch_models.dart';
import '../domain/models/ambulance.dart';
import '../domain/models/intervention.dart';
import 'ambulance_schema.dart';

class InterventionRepository {
  Future<Database> get _db => AmbulanceSchema.database;

  static const String _select = '''
    SELECT i.*, a.immatriculation, a.type AS type_ambulance,
      p.prenom AS patient_prenom, p.nom AS patient_nom
    FROM interventions i
    LEFT JOIN ambulances a ON a.id = i.ambulance_id
    LEFT JOIN patients p ON p.id = i.patient_id
  ''';

  /// Recherche multicritère. [statuts] vide = tous les statuts.
  Future<List<InterventionDetail>> rechercher({
    String texte = '',
    List<StatutIntervention> statuts = const [],
    Gravite? gravite,
    int? ambulanceId,
    int? patientId,
    DateTime? depuis,
    int? limite,
  }) async {
    final Database db = await _db;
    final List<String> conditions = [];
    final List<Object?> args = [];

    final String t = texte.trim();
    if (t.isNotEmpty) {
      conditions.add(
        '(i.adresse LIKE ? OR a.immatriculation LIKE ? OR p.nom LIKE ? OR p.prenom LIKE ?)',
      );
      for (int k = 0; k < 4; k++) {
        args.add('%$t%');
      }
    }
    if (statuts.isNotEmpty) {
      final List<String> marques = [];
      for (final StatutIntervention s in statuts) {
        marques.add('?');
        args.add(s.code);
      }
      conditions.add('i.statut IN (${marques.join(', ')})');
    }
    if (gravite != null) {
      conditions.add('i.gravite = ?');
      args.add(gravite.code);
    }
    if (ambulanceId != null) {
      conditions.add('i.ambulance_id = ?');
      args.add(ambulanceId);
    }
    if (patientId != null) {
      conditions.add('i.patient_id = ?');
      args.add(patientId);
    }
    if (depuis != null) {
      conditions.add('i.heure_appel >= ?');
      args.add(depuis.toIso8601String());
    }
    final String where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final String limit = limite == null ? '' : 'LIMIT $limite';

    final List<Map<String, Object?>> rows = await db.rawQuery(
      '$_select $where ORDER BY i.heure_appel DESC $limit',
      args,
    );
    return _details(rows);
  }

  Future<InterventionDetail?> detailParId(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('$_select WHERE i.id = ? LIMIT 1', [id]);
    final List<InterventionDetail> res = _details(rows);
    return res.isEmpty ? null : res.first;
  }

  Future<Intervention?> parId(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    final List<Map<String, Object?>> rows =
        await e.query('interventions', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Intervention.fromMap(rows.first);
  }

  /// Interventions non clôturées (en attente + ambulance engagée).
  Future<List<Intervention>> ouvertes({DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    final List<Map<String, Object?>> rows = await e.query(
      'interventions',
      where: 'statut IN (?, ?, ?, ?, ?)',
      whereArgs: [
        StatutIntervention.enAttente.code,
        StatutIntervention.assignee.code,
        StatutIntervention.enRoute.code,
        StatutIntervention.surPlace.code,
        StatutIntervention.transport.code,
      ],
      orderBy: 'heure_appel',
    );
    final List<Intervention> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Intervention.fromMap(r));
    }
    return res;
  }

  /// File d'attente : la plus grave d'abord, puis la plus ancienne.
  Future<List<Intervention>> fileAttente({DatabaseExecutor? exec}) async {
    final List<Intervention> toutes = await ouvertes(exec: exec);
    final List<Intervention> attente = [];
    for (final Intervention i in toutes) {
      if (i.statut == StatutIntervention.enAttente) {
        attente.add(i);
      }
    }
    attente.sort((Intervention a, Intervention b) {
      final int g = a.gravite.priorite.compareTo(b.gravite.priorite);
      return g != 0 ? g : a.heureAppel.compareTo(b.heureAppel);
    });
    return attente;
  }

  /// Mission en cours de l'ambulance (au plus une).
  Future<Intervention?> activePourAmbulance(
    int ambulanceId, {
    DatabaseExecutor? exec,
  }) async {
    final List<Intervention> toutes = await ouvertes(exec: exec);
    for (final Intervention i in toutes) {
      if (i.ambulanceId == ambulanceId && i.statut.estActive) {
        return i;
      }
    }
    return null;
  }

  Future<int> inserer(Intervention i, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('interventions', i.toMap());
  }

  Future<void> modifier(Intervention i, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('interventions', i.toMap(), where: 'id = ?', whereArgs: [i.id]);
  }

  /// Mise à jour partielle (statut, heures, ambulance...).
  Future<void> mettreAJour(
    int id,
    Map<String, Object?> valeurs, {
    DatabaseExecutor? exec,
  }) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('interventions', valeurs, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> supprimer(int id) async {
    final Database db = await _db;
    await db.delete('interventions', where: 'id = ?', whereArgs: [id]);
  }

  /// Points de la heatmap (toutes les interventions sauf annulées).
  Future<List<Intervention>> pourHeatmap({DateTime? depuis, Gravite? gravite}) async {
    final List<InterventionDetail> res = await rechercher(
      depuis: depuis,
      gravite: gravite,
    );
    final List<Intervention> points = [];
    for (final InterventionDetail d in res) {
      if (d.intervention.statut != StatutIntervention.annulee) {
        points.add(d.intervention);
      }
    }
    return points;
  }

  List<InterventionDetail> _details(List<Map<String, Object?>> rows) {
    final List<InterventionDetail> res = [];
    for (final Map<String, Object?> r in rows) {
      final Object? nom = r['patient_nom'];
      final Object? type = r['type_ambulance'];
      res.add(InterventionDetail(
        intervention: Intervention.fromMap(r),
        immatriculation: r['immatriculation'] as String?,
        typeAmbulance: type == null ? null : TypeAmbulance.depuisCode(type as String),
        patientNom: nom == null ? null : '${r['patient_prenom']} $nom',
      ));
    }
    return res;
  }
}
