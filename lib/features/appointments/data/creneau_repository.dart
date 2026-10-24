import 'package:sqflite/sqflite.dart';

import '../domain/rdv_models.dart';
import 'rdv_schema.dart';

/// Disponibilités des médecins (table `creneaux`).
class CreneauRepository {
  Future<List<Creneau>> parMedecin(int medecinId) async {
    final Database db = await RdvSchema.db;
    final List<Map<String, Object?>> rows = await db.query(
      'creneaux',
      where: 'medecin_id = ?',
      whereArgs: [medecinId],
      orderBy: 'recurrent DESC, jour, date, heure_debut',
    );
    final List<Creneau> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Creneau.fromMap(r));
    }
    return res;
  }

  Future<int> inserer(Creneau c) async {
    final Database db = await RdvSchema.db;
    return db.insert('creneaux', c.toMap());
  }

  Future<void> modifier(Creneau c) async {
    final Database db = await RdvSchema.db;
    await db.update('creneaux', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> supprimer(int id) async {
    final Database db = await RdvSchema.db;
    await db.delete('creneaux', where: 'id = ?', whereArgs: [id]);
  }
}
