import '../../../models/patient.dart';
import '../data/ligne_ordonnance_repository.dart';
import '../data/prise_repository.dart';
import 'dates_sql.dart';
import 'models/prise.dart';
import 'models/vues_traitement.dart';
import 'service_patients.dart';

/// Patient en dessous du seuil d'observance (suivi par le médecin).
class AlerteObservance {
  const AlerteObservance({required this.patientId, required this.patientNom, required this.observance});

  final int patientId;
  final String patientNom;

  /// En % (ex. 71.4).
  final double observance;
}

/// Métiers 3 et 4 côté patient : planning du jour, observance, fin de stock.
class TraitementManager {
  TraitementManager({
    PriseRepository? prises,
    LigneOrdonnanceRepository? lignes,
    ServicePatients? patients,
  })  : _prises = prises ?? PriseRepository(),
        _lignes = lignes ?? LigneOrdonnanceRepository(),
        _patients = patients ?? ServicePatients.instance;

  final PriseRepository _prises;
  final LigneOrdonnanceRepository _lignes;
  final ServicePatients _patients;

  /// Seuil d'observance sous lequel le médecin est prévenu.
  static const double seuilObservance = 80;

  /// Délai après l'heure prévue avant qu'une prise passe en « oubliée ».
  static const Duration delaiOubli = Duration(hours: 3);

  /// Délai après l'heure prévue avant le rappel.
  static const Duration delaiRappel = Duration(minutes: 30);

  /// Prises encore « prévues » 3 h après leur heure → « oubliée ».
  Future<int> marquerOubliees() {
    return _prises.marquerOubliees(DateTime.now().subtract(delaiOubli));
  }

  /// Planning d'une journée (passe d'abord les prises trop anciennes en « oubliée »).
  Future<List<PrisePlanifiee>> planningDuJour(int patientId, DateTime jour) async {
    await marquerOubliees();
    final DateTime debut = DatesSql.jour(jour);
    final DateTime fin = debut.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    return _prises.planning(patientId, debut, fin);
  }

  /// Prochaine prise prévue du patient (carte de l'accueil).
  Future<PrisePlanifiee?> prochainePrise(int patientId) async {
    final DateTime maintenant = DateTime.now();
    final List<PrisePlanifiee> prises = await _prises.planning(
      patientId,
      maintenant.subtract(delaiOubli),
      maintenant.add(const Duration(days: 2)),
    );
    for (final PrisePlanifiee p in prises) {
      if (p.prise.statut == StatutPrise.prevue) {
        return p;
      }
    }
    return null;
  }

  Future<void> cocher(int priseId, StatutPrise statut) {
    return _prises.marquer(
      priseId,
      statut,
      heureReelle: statut == StatutPrise.prise ? DateTime.now() : null,
    );
  }

  /// Observance sur 7 jours glissants, en % ; null si aucune prise échue.
  Future<double?> observance(int patientId) => _prises.observance(patientId);

  Future<List<ObservanceJour>> observanceParJour(int patientId) {
    return _prises.observanceParJour(patientId);
  }

  /// Médicaments en cours avec leur stock (alerte à 3 jours ou moins).
  Future<List<StockTraitement>> stocks(int patientId) => _lignes.stocks(patientId);

  /// Patients du médecin dont l'observance est sous 80 % (jamais dans la
  /// table alerte de la gestion Patients : c'est une notification du module).
  Future<List<AlerteObservance>> alertesObservance(int medecinId) async {
    await marquerOubliees();
    final List<AlerteObservance> res = [];
    for (final Patient patient in await _patients.patientsDuMedecin(medecinId)) {
      final int? id = patient.id;
      if (id == null) {
        continue;
      }
      final double? taux = await _prises.observance(id);
      if (taux != null && taux < seuilObservance) {
        res.add(AlerteObservance(patientId: id, patientNom: patient.nomComplet, observance: taux));
      }
    }
    return res;
  }
}
