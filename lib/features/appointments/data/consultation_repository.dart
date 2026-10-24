import 'package:sqflite/sqflite.dart';

import '../domain/rdv_models.dart';
import 'rdv_schema.dart';

/// Comptes-rendus de consultation (table `consultations`).
class ConsultationRepository {
  Future<Consultation?> parRdv(int rdvId) async {
    final Database db = await RdvSchema.db;
    final List<Map<String, Object?>> rows = await db.query(
      'consultations',
      where: 'rdv_id = ?',
      whereArgs: [rdvId],
      limit: 1,
    );
    return rows.isEmpty ? null : Consultation.fromMap(rows.first);
  }

  /// Crée ou remplace la consultation du RDV (une seule par RDV).
  Future<int> enregistrer(Consultation c, {DatabaseExecutor? exec}) async {
    final DatabaseExecutor e = exec ?? await RdvSchema.db;
    return e.insert(
      'consultations',
      c.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
