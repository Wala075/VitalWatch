import 'package:sqflite/sqflite.dart';

import '../domain/rdv_models.dart';
import 'rdv_schema.dart';

/// Notifications in-app :
/// - médecin : table `notifications_rdv` (appel urgent d'un patient) ;
/// - patient : table `notifications_patient` (RDV pris pour lui par le personnel).
class NotificationRepository {
  static const String typeAppelUrgent = 'appel_urgent';
  static const String typeRdvCree = 'rdv_cree';

  Future<void> creer({
    required int rdvId,
    required int medecinId,
    required String type,
  }) async {
    final Database db = await RdvSchema.db;
    await db.insert('notifications_rdv', {
      'rdv_id': rdvId,
      'medecin_id': medecinId,
      'type': type,
      'lu': 0,
      'date_creation': DateTime.now().toIso8601String(),
    });
  }

  /// Notifications non lues du médecin dont le RDV est encore actif
  /// (un RDV annulé ou terminé ne sonne plus).
  Future<List<NotificationRdv>> nonLues(int medecinId) async {
    final Database db = await RdvSchema.db;
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT n.id, n.rdv_id, n.type, n.date_creation
      FROM notifications_rdv n
      JOIN rendez_vous r ON r.id = n.rdv_id
      WHERE n.medecin_id = ? AND n.lu = 0 AND r.statut IN (?, ?)
      ORDER BY n.date_creation
    ''', [medecinId, StatutRdv.enAttente.name, StatutRdv.confirme.name]);
    return [
      for (final Map<String, Object?> r in rows)
        NotificationRdv(
          id: r['id'] as int,
          rdvId: r['rdv_id'] as int,
          type: r['type'] as String,
          date: DateTime.parse(r['date_creation'] as String),
        ),
    ];
  }

  Future<void> marquerLue(int id) async {
    final Database db = await RdvSchema.db;
    await db.update('notifications_rdv', {'lu': 1}, where: 'id = ?', whereArgs: [id]);
  }
}

// ---------------------------------------------------------------------
// Côté patient
// ---------------------------------------------------------------------

/// Notifications du patient (table `notifications_patient`).
class NotificationPatientRepository {
  Future<void> creer({
    required int rdvId,
    required int patientId,
    required String type,
  }) async {
    final Database db = await RdvSchema.db;
    await db.insert('notifications_patient', {
      'rdv_id': rdvId,
      'patient_id': patientId,
      'type': type,
      'lu': 0,
      'date_creation': DateTime.now().toIso8601String(),
    });
  }

  /// Non lues, dont le RDV n'est ni annulé ni terminé.
  Future<List<NotificationRdv>> nonLues(int patientId) async {
    final Database db = await RdvSchema.db;
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT n.id, n.rdv_id, n.type, n.date_creation
      FROM notifications_patient n
      JOIN rendez_vous r ON r.id = n.rdv_id
      WHERE n.patient_id = ? AND n.lu = 0 AND r.statut IN (?, ?)
      ORDER BY n.date_creation
    ''', [patientId, StatutRdv.enAttente.name, StatutRdv.confirme.name]);
    return [
      for (final Map<String, Object?> r in rows)
        NotificationRdv(
          id: r['id'] as int,
          rdvId: r['rdv_id'] as int,
          type: r['type'] as String,
          date: DateTime.parse(r['date_creation'] as String),
        ),
    ];
  }

  Future<void> marquerLue(int id) async {
    final Database db = await RdvSchema.db;
    await db.update('notifications_patient', {'lu': 1}, where: 'id = ?', whereArgs: [id]);
  }
}

class NotificationRdv {
  const NotificationRdv({
    required this.id,
    required this.rdvId,
    required this.type,
    required this.date,
  });

  final int id;
  final int rdvId;
  final String type;
  final DateTime date;
}
