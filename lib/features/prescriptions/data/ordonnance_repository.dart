import 'package:sqflite/sqflite.dart';

import '../domain/dates_sql.dart';
import '../domain/models/ordonnance.dart';
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
