import 'package:sqflite/sqflite.dart';

import '../../../models/patient.dart';
import '../data/prescriptions_schema.dart';

/// Résultat du contrôle allergies / interactions de la gestion Patients.
enum NiveauAnalyse { ok, attention, bloquant }

class AnalyseTraitement {
  const AnalyseTraitement(this.niveau, [this.message]);

  static const AnalyseTraitement aucunRisque = AnalyseTraitement(NiveauAnalyse.ok);

  final NiveauAnalyse niveau;
  final String? message;
}

/// Fonctions fournies par la gestion Patients (Abir) et appelées par les
/// ordonnances. Aucune donnée n'est copiée : on pose la question à sa gestion.
///
/// Tant que sa branche n'est pas prête, [instance] est une version
/// provisoire. Pour brancher la sienne : ServicePatients.instance = SaVersion();
abstract class ServicePatients {
  static ServicePatients instance = ServicePatientsProvisoire();

  /// Allergies et interactions d'un médicament (DCI) avec les autres
  /// médicaments du patient. Un résultat « bloquant » empêche la validation.
  Future<AnalyseTraitement> analyserTraitement(int patientId, String dci, List<String> autresDci);

  /// Codes CIM-10 des maladies chroniques du patient (éligibilité APCI).
  Future<List<String>> codesCimChroniques(int patientId);

  /// Contrôle d'accès : patients suivis par un médecin.
  Future<List<Patient>> patientsDuMedecin(int medecinId);
}

/// Version provisoire en attendant la gestion Patients :
/// - aucune allergie connue, donc aucun blocage ;
/// - maladies chroniques = codes APCI des contrats du patient ;
/// - un médecin suit les patients dont il est le médecin référent.
class ServicePatientsProvisoire implements ServicePatients {
  Future<Database> get _db => PrescriptionsSchema.database;

  @override
  Future<AnalyseTraitement> analyserTraitement(
    int patientId,
    String dci,
    List<String> autresDci,
  ) async {
    return AnalyseTraitement.aucunRisque;
  }

  @override
  Future<List<String>> codesCimChroniques(int patientId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'contrat_assurance',
      columns: ['code_apci'],
      where: 'patient_id = ? AND apci = 1 AND code_apci IS NOT NULL',
      whereArgs: [patientId],
    );
    final List<String> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(r['code_apci'] as String);
    }
    return res;
  }

  @override
  Future<List<Patient>> patientsDuMedecin(int medecinId) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'patients',
      where: 'medecin_id = ?',
      whereArgs: [medecinId],
      orderBy: 'nom COLLATE NOCASE, prenom COLLATE NOCASE',
    );
    final List<Patient> res = [];
    for (final Map<String, Object?> r in rows) {
      res.add(Patient.fromMap(r));
    }
    return res;
  }
}
