import 'package:sqflite/sqflite.dart';

import '../domain/dates_sql.dart';
import '../domain/models/ordonnance.dart';
import '../domain/models/vues_ordonnance.dart';
import 'numerotation.dart';
import 'prescriptions_schema.dart';

/// Une ordonnance validée ne se modifie pas (déclencheurs) : après la
/// validation, on ne change que le statut, les renouvellements et le motif.
class OrdonnanceRepository {
  Future<Database> get _db => PrescriptionsSchema.database;

  /// Historique : filtres patient, médecin, statut et période (date d'émission).
  Future<List<Ordonnance>> lister({
    int? patientId,
    int? medecinId,
    StatutOrdonnance? statut,
    DateTime? du,
    DateTime? au,
  }) async {
    final Database db = await _db;
    final List<String> conditions = [];
    final List<Object?> args = [];

    if (patientId != null) {
      conditions.add('patient_id = ?');
      args.add(patientId);
    }
    if (medecinId != null) {
      conditions.add('medecin_id = ?');
      args.add(medecinId);
    }
    if (statut != null) {
      conditions.add('statut = ?');
      args.add(statut.valeur);
    }
    if (du != null) {
      conditions.add('date_emission >= ?');
      args.add(DatesSql.date(du));
    }
    if (au != null) {
      conditions.add('date_emission <= ?');
      args.add(DatesSql.date(au));
    }

    final List<Map<String, Object?>> rows = await db.query(
      'ordonnance',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date_emission DESC, id DESC',
    );
    final List<Ordonnance> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Ordonnance.fromMap(r));
    }
    return res;
  }

  /// Requête commune des résumés : ordonnance + patient + médecin + nb de lignes.
  static const String _selectResume = '''
    SELECT o.*,
      p.prenom AS p_prenom, p.nom AS p_nom,
      m.prenom AS m_prenom, m.nom AS m_nom,
      origine.numero AS origine_numero,
      (SELECT COUNT(*) FROM ligne_ordonnance l WHERE l.ordonnance_id = o.id) AS nb_lignes
    FROM ordonnance o
    LEFT JOIN patients p ON p.id = o.patient_id
    LEFT JOIN medecins m ON m.id = o.medecin_id
    LEFT JOIN ordonnance origine ON origine.id = o.ordonnance_origine_id
  ''';

  /// Historique avec noms : filtres médecin, patient, statuts, période et
  /// recherche (nom du patient ou numéro).
  Future<List<OrdonnanceResume>> listerResumes({
    int? medecinId,
    int? patientId,
    List<StatutOrdonnance>? statuts,
    DateTime? du,
    String texte = '',
  }) async {
    final Database db = await _db;
    final List<String> conditions = [];
    final List<Object?> args = [];

    if (medecinId != null) {
      conditions.add('o.medecin_id = ?');
      args.add(medecinId);
    }
    if (patientId != null) {
      conditions.add('o.patient_id = ?');
      args.add(patientId);
    }
    if (statuts != null && statuts.isNotEmpty) {
      final List<String> marques = [];
      for (final StatutOrdonnance s in statuts) {
        marques.add('?');
        args.add(s.valeur);
      }
      conditions.add('o.statut IN (${marques.join(', ')})');
    }
    if (du != null) {
      conditions.add('o.date_emission >= ?');
      args.add(DatesSql.date(du));
    }
    final String t = texte.trim();
    if (t.isNotEmpty) {
      conditions.add('(p.nom LIKE ? OR p.prenom LIKE ? OR o.numero LIKE ?)');
      args.add('%$t%');
      args.add('%$t%');
      args.add('%$t%');
    }
    final String where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final List<Map<String, Object?>> rows = await db.rawQuery(
      '$_selectResume $where ORDER BY o.date_emission DESC, o.id DESC',
      args,
    );
    final List<OrdonnanceResume> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(_resume(r));
    }
    return res;
  }

  Future<OrdonnanceResume?> resume(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('$_selectResume WHERE o.id = ?', [id]);
    return rows.isEmpty ? null : _resume(rows.first);
  }

  /// Coordonnées du médecin et du patient pour le PDF.
  Future<Map<String, Object?>?> entete(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT m.specialite AS m_specialite, m.matricule AS m_matricule,
        m.telephone AS m_telephone, m.email AS m_email,
        p.cin AS p_cin, p.date_naissance AS p_date_naissance,
        p.telephone AS p_telephone, p.groupe_sanguin AS p_groupe
      FROM ordonnance o
      LEFT JOIN medecins m ON m.id = o.medecin_id
      LEFT JOIN patients p ON p.id = o.patient_id
      WHERE o.id = ?
    ''', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  OrdonnanceResume _resume(Map<String, Object?> r) {
    final Object? pNom = r['p_nom'];
    final Object? mNom = r['m_nom'];
    return OrdonnanceResume(
      ordonnance: Ordonnance.fromMap(r),
      patientNom: pNom == null ? 'Patient supprimé' : '${r['p_prenom']} $pNom',
      medecinNom: mNom == null ? 'Médecin supprimé' : 'Dr ${r['m_prenom']} $mNom',
      nbLignes: (r['nb_lignes'] as int?) ?? 0,
      origineNumero: r['origine_numero'] as String?,
    );
  }

  /// Médicaments en cours chez un patient : lignes des ordonnances validées
  /// ou délivrées dont la durée de traitement n'est pas terminée.
  Future<List<TraitementActif>> traitementsActifs(int patientId, {int? exclureOrdonnanceId}) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT o.id AS ordonnance_id, o.numero, o.medecin_id,
        m.prenom AS m_prenom, m.nom AS m_nom,
        med.dci, med.nom_commercial, med.dosage
      FROM ligne_ordonnance l
      JOIN ordonnance o ON o.id = l.ordonnance_id
      JOIN medicament med ON med.id = l.medicament_id
      LEFT JOIN medecins m ON m.id = o.medecin_id
      WHERE o.patient_id = ? AND o.id != ?
        AND o.statut IN ('validee', 'partiellement_delivree', 'delivree')
        AND date(o.date_emission, '+' || l.duree_jours || ' days') >= ?
      ORDER BY o.date_emission DESC
    ''', [patientId, exclureOrdonnanceId ?? -1, DatesSql.date(DateTime.now())]);

    final List<TraitementActif> res = [];
    for (final Map<String, Object?> r in rows) {
      final Object? mNom = r['m_nom'];
      res.add(TraitementActif(
        ordonnanceId: r['ordonnance_id'] as int,
        numero: r['numero'] as String,
        medecinId: r['medecin_id'] as int,
        medecinNom: mNom == null ? 'un autre médecin' : 'Dr ${r['m_prenom']} $mNom',
        dci: r['dci'] as String,
        medicament: '${r['nom_commercial']} ${r['dosage']}',
      ));
    }
    return res;
  }

  Future<Ordonnance?> parId(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    final List<Map<String, Object?>> rows =
        await e.query('ordonnance', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Ordonnance.fromMap(rows.first);
  }

  /// Retrouve l'ordonnance d'un QR code.
  Future<Ordonnance?> parNumero(String numero) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'ordonnance',
      where: 'numero = ?',
      whereArgs: [numero.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : Ordonnance.fromMap(rows.first);
  }

  Future<String> prochainNumero(int annee, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return Numerotation.prochain(e, table: 'ordonnance', prefixe: 'ORD', annee: annee);
  }

  Future<int> inserer(Ordonnance o, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.insert('ordonnance', o.toMap());
  }

  /// Brouillon uniquement.
  Future<void> modifier(Ordonnance o, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('ordonnance', o.toMap(), where: 'id = ?', whereArgs: [o.id]);
  }

  /// Passage en « validée » avec la signature.
  Future<void> valider(int id, String hash, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update(
      'ordonnance',
      {'statut': StatutOrdonnance.validee.valeur, 'hash_signature': hash},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> changerStatut(int id, StatutOrdonnance statut, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('ordonnance', {'statut': statut.valeur}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> annuler(int id, String motif, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update(
      'ordonnance',
      {'statut': StatutOrdonnance.annulee.valeur, 'motif_annulation': motif.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> changerRenouvellements(int id, int nb, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.update('ordonnance', {'nb_renouvellements': nb}, where: 'id = ?', whereArgs: [id]);
  }

  /// Brouillon uniquement (lignes et prises supprimées en cascade).
  Future<void> supprimer(int id, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete('ordonnance', where: 'id = ?', whereArgs: [id]);
  }

  /// Métier 1 : ordonnances actives dont la date d'expiration est passée.
  Future<int> expirerPerimees({DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await _db;
    return e.rawUpdate(PrescriptionsSchema.sqlExpiration, [DatesSql.date(DateTime.now())]);
  }
}
