class AppConstants {
  AppConstants._();

  static const String appName = 'VitalWatch';

  // Noms des collections Firestore (à figer en groupe pour éviter les doublons)
  static const String colUtilisateurs = 'utilisateurs';
  static const String colPatients = 'patients';
  static const String colMedecins = 'medecins';
  static const String colServices = 'services';
  static const String colAmbulances = 'ambulances';
  static const String colInterventions = 'interventions';
  static const String colRendezVous = 'rendez_vous';
  static const String colOrdonnances = 'ordonnances';
  static const String colMesures = 'mesures_vitales';
  static const String colAlertes = 'alertes';
}
