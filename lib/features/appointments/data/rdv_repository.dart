import 'package:sqflite/sqflite.dart';

import '../domain/rdv_models.dart';
import 'rdv_schema.dart';

/// Rendez-vous (table `rendez_vous`) + jointures patient / médecin / service.
class RdvRepository {
  /// Fenêtre dans laquelle une alerte du module Patients rend le RDV prioritaire.
  static const Duration fenetreAlerte = Duration(hours: 48);

  static bool? _tableAlertes;

  /// Le module 2 (Patients) crée la table `alertes` : tant qu'elle n'existe
  /// pas, on ignore simplement cette règle (pas d'erreur).
  Future<bool> _alertesDisponibles(Database db) async {
    final bool? connu = _tableAlertes;
    if (connu != null) {
      return connu;
    }
    final List<Map<String, Object?>> cols =
        await db.rawQuery('PRAGMA table_info(alertes)');
    final Set<String> noms = {for (final Map<String, Object?> c in cols) c['name'] as String};
    final bool ok = noms.containsAll(['patient_id', 'date_heure']);
    // On ne mémorise que le succès : la table peut apparaître plus tard.
    if (ok) {
      _tableAlertes = true;
    }
    return ok;
  }

  Future<String> _selectDetail(Database db, List<Object?> args) async {
    String alerte = '0';
    if (await _alertesDisponibles(db)) {
      alerte = '(SELECT COUNT(*) FROM alertes a WHERE a.patient_id = r.patient_id '
          'AND a.date_heure >= ?)';
      args.add(DateTime.now().subtract(fenetreAlerte).toIso8601String());
    }
    return '''
      SELECT r.*,
        p.prenom AS p_prenom, p.nom AS p_nom,
        m.prenom AS m_prenom, m.nom AS m_nom, m.specialite AS m_specialite,
        s.nom AS service_nom,
        $alerte AS nb_alertes
      FROM rendez_vous r
      JOIN patients p ON p.id = r.patient_id
      JOIN medecins m ON m.id = r.medecin_id
      LEFT JOIN services s ON s.id = m.service_id
    ''';
  }

  RdvDetail _detail(Map<String, Object?> r) {
    return RdvDetail(
      rdv: RendezVous.fromMap(r),
      patientNom: '${r['p_prenom']} ${r['p_nom']}',
      medecinNom: 'Dr ${r['m_prenom']} ${r['m_nom']}',
      specialite: r['m_specialite'] as String?,
      serviceNom: r['service_nom'] as String?,
      alerteRecente: ((r['nb_alertes'] as int?) ?? 0) > 0,
    );
  }

  /// Recherche multicritère (texte : patient, médecin, motif).
  Future<List<RdvDetail>> rechercher(
    RdvFiltre f, {
    bool recentsDabord = false,
  }) async {
    final Database db = await RdvSchema.db;
    final List<Object?> args = [];
    final String select = await _selectDetail(db, args);
    final List<String> conditions = [];

    final String t = f.texte.trim();
    if (t.isNotEmpty) {
      conditions.add('(p.nom LIKE ? OR p.prenom LIKE ? OR m.nom LIKE ? '
          'OR m.prenom LIKE ? OR r.motif LIKE ?)');
      for (int i = 0; i < 5; i++) {
        args.add('%$t%');
      }
    }
    final int? medecinId = f.medecinId;
    if (medecinId != null) {
      conditions.add('r.medecin_id = ?');
      args.add(medecinId);
    }
    final int? patientId = f.patientId;
    if (patientId != null) {
      conditions.add('r.patient_id = ?');
      args.add(patientId);
    }
    final StatutRdv? statut = f.statut;
    if (statut != null) {
      conditions.add('r.statut = ?');
      args.add(statut.name);
    }
    final TypeRdv? type = f.type;
    if (type != null) {
      conditions.add('r.type = ?');
      args.add(type.name);
    }
    final DateTime? jour = f.jour;
    if (jour != null) {
      final DateTime debut = DateTime(jour.year, jour.month, jour.day);
      conditions.add('r.date_heure >= ? AND r.date_heure < ?');
      args.add(debut.toIso8601String());
      args.add(debut.add(const Duration(days: 1)).toIso8601String());
    }
    final String where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final String ordre = recentsDabord ? 'DESC' : 'ASC';

    final List<Map<String, Object?>> rows = await db.rawQuery(
      '$select $where ORDER BY r.date_heure $ordre',
      args,
    );
    return [for (final Map<String, Object?> r in rows) _detail(r)];
  }

  Future<RdvDetail?> detail(int id) async {
    final Database db = await RdvSchema.db;
    final List<Object?> args = [];
    final String select = await _selectDetail(db, args);
    args.add(id);
    final List<Map<String, Object?>> rows =
        await db.rawQuery('$select WHERE r.id = ? LIMIT 1', args);
    return rows.isEmpty ? null : _detail(rows.first);
  }

  /// RDV actifs (en attente, confirmés, en cours) d'un médecin entre deux dates.
  Future<List<RendezVous>> actifsMedecin(
    int medecinId,
    DateTime debut,
    DateTime fin, {
    int? exclureId,
  }) {
    return _actifs('medecin_id', medecinId, debut, fin, exclureId);
  }

  /// RDV actifs d'un patient entre deux dates (un patient n'a pas deux RDV en même temps).
  Future<List<RendezVous>> actifsPatient(
    int patientId,
    DateTime debut,
    DateTime fin, {
    int? exclureId,
  }) {
    return _actifs('patient_id', patientId, debut, fin, exclureId);
  }

  Future<List<RendezVous>> _actifs(
    String colonne,
    int id,
    DateTime debut,
    DateTime fin,
    int? exclureId,
  ) async {
    final Database db = await RdvSchema.db;
    // Marge de 4 h avant le début pour attraper les RDV longs qui débordent.
    final List<Map<String, Object?>> rows = await db.query(
      'rendez_vous',
      where: '$colonne = ? AND statut IN (?, ?, ?) '
          'AND date_heure >= ? AND date_heure < ? AND id != ?',
      whereArgs: [
        id,
        StatutRdv.enAttente.name,
        StatutRdv.confirme.name,
        StatutRdv.enCours.name,
        debut.subtract(const Duration(hours: 4)).toIso8601String(),
        fin.toIso8601String(),
        exclureId ?? -1,
      ],
      orderBy: 'date_heure',
    );
    return [for (final Map<String, Object?> r in rows) RendezVous.fromMap(r)];
  }

  /// Nombre de RDV actifs du médecin aujourd'hui (pour choisir le moins chargé).
  Future<int> chargeDuJour(int medecinId, DateTime jour) async {
    final Database db = await RdvSchema.db;
    final DateTime debut = DateTime(jour.year, jour.month, jour.day);
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM rendez_vous WHERE medecin_id = ? '
      'AND statut IN (?, ?, ?) AND date_heure >= ? AND date_heure < ?',
      [
        medecinId,
        StatutRdv.enAttente.name,
        StatutRdv.confirme.name,
        StatutRdv.enCours.name,
        debut.toIso8601String(),
        debut.add(const Duration(days: 1)).toIso8601String(),
      ],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<bool> alerteRecente(int patientId) async {
    final Database db = await RdvSchema.db;
    if (!await _alertesDisponibles(db)) {
      return false;
    }
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM alertes WHERE patient_id = ? AND date_heure >= ?',
      [patientId, DateTime.now().subtract(fenetreAlerte).toIso8601String()],
    );
    return ((rows.first['n'] as int?) ?? 0) > 0;
  }

  Future<int> inserer(RendezVous r, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await RdvSchema.db;
    return e.insert('rendez_vous', r.toMap());
  }

  Future<void> modifier(RendezVous r, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await RdvSchema.db;
    await e.update('rendez_vous', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> changerStatut(
    int id,
    StatutRdv statut, {
    String? motifAnnulation,
    DatabaseExecutor? exec,
  }) async {
    final DatabaseExecutor e = exec ?? await RdvSchema.db;
    await e.update(
      'rendez_vous',
      {
        'statut': statut.name,
        if (motifAnnulation != null) 'motif_annulation': motifAnnulation,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> definirLienVisio(int id, String lien) async {
    final Database db = await RdvSchema.db;
    await db.update(
      'rendez_vous',
      {'lien_visio': lien},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Données brutes pour les statistiques (RDV + durée réelle éventuelle).
  Future<List<Map<String, Object?>>> lignesStats({int? medecinId}) async {
    final Database db = await RdvSchema.db;
    return db.rawQuery('''
      SELECT m.id AS medecin_id, m.prenom, m.nom,
        r.statut, r.date_heure, c.duree_reelle
      FROM medecins m
      LEFT JOIN rendez_vous r ON r.medecin_id = m.id
      LEFT JOIN consultations c ON c.rdv_id = r.id
      ${medecinId == null ? '' : 'WHERE m.id = ?'}
      ORDER BY m.nom COLLATE NOCASE, m.prenom COLLATE NOCASE
    ''', medecinId == null ? [] : [medecinId]);
  }
}
