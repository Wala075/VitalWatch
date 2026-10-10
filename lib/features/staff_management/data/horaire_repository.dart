import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../domain/disponibilite.dart';

/// Horaires de consultation des médecins (table `horaires_medecins`).
class HoraireRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<List<Creneau>> parMedecin(int medecinId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'horaires_medecins',
      where: 'medecin_id = ?',
      whereArgs: [medecinId],
      orderBy: 'jour, debut',
    );
    final List<Creneau> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Creneau.fromMap(r));
    }
    return res;
  }

  /// Tous les horaires, regroupés par médecin.
  Future<Map<int, List<Creneau>>> tous() async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows =
        await db.query('horaires_medecins', orderBy: 'medecin_id, jour, debut');
    final Map<int, List<Creneau>> res = {};
    for (final Map<String, Object?> r in rows) {
      final Creneau c = Creneau.fromMap(r);
      res.putIfAbsent(c.medecinId, () => []).add(c);
    }
    return res;
  }

  Future<void> remplacer(
    int medecinId,
    List<Creneau> creneaux, {
    DatabaseExecutor? exec,
  }) async {
    final DatabaseExecutor e = exec ?? await _db;
    await e.delete(
      'horaires_medecins',
      where: 'medecin_id = ?',
      whereArgs: [medecinId],
    );
    for (final Creneau c in creneaux) {
      await e.insert(
        'horaires_medecins',
        Creneau(medecinId: medecinId, jour: c.jour, debut: c.debut, fin: c.fin)
            .toMap(),
      );
    }
  }

  /// Horaires d'un nouveau médecin : du lundi au vendredi, 09:00 – 17:00.
  Future<void> parDefaut(int medecinId, {DatabaseExecutor? exec}) {
    return remplacer(
      medecinId,
      [
        for (int j = 1; j <= 5; j++)
          Creneau(medecinId: medecinId, jour: j, debut: 9 * 60, fin: 17 * 60),
      ],
      exec: exec,
    );
  }
}
