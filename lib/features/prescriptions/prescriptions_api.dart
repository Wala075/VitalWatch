// Ce que le module Ordonnances & Assurance fournit aux autres gestions.
//
// Gestion Patients (Abir) :
// - `traitementsActifs(patientId)` : médicaments en cours, en lecture seule
//   dans la fiche patient ;
// - `OrdonnancesPatientTab(patientId: …)` : onglet « Ordonnances » de la
//   fiche patient (traitements, ordonnances, contrats et dossiers).
//
// Dans l'autre sens, la gestion Patients branche ses fonctions ici :
// `ServicePatients.instance = SaVersion();`

import 'data/ordonnance_repository.dart';
import 'domain/models/vues_ordonnance.dart';

export 'domain/models/vues_ordonnance.dart' show TraitementActif;
export 'domain/service_patients.dart' show AnalyseTraitement, NiveauAnalyse, ServicePatients;
export 'presentation/widgets/ordonnances_patient_tab.dart' show OrdonnancesPatientTab;

/// Médicaments en cours d'un patient (ordonnances validées ou délivrées dont
/// la durée de traitement n'est pas terminée).
Future<List<TraitementActif>> traitementsActifs(int patientId) {
  return OrdonnanceRepository().traitementsActifs(patientId);
}
