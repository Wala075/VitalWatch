/// Constantes de routes — chaque module complète UNIQUEMENT sa section
/// pour limiter les conflits Git.
class AppRoutes {
  AppRoutes._();

  // ===== Commun =====
  static const String splash = '/splash';
  static const String home = '/';
  static const String login = '/login';

  // ===== Module 1 : Services & Personnel =====
  static const String staff = '/staff';

  // ===== Module 2 : Patients & Suivi vital =====
  static const String patientMonitoring = '/patient-monitoring';

  // ===== Module 3 : Ambulances & Interventions =====
  static const String ambulanceDispatch = '/ambulance-dispatch';

  // ===== Module 4 : Rendez-vous & Téléconsultation =====
  static const String appointments = '/appointments';

  // ===== Module 5 : Ordonnances & Traitements =====
  static const String prescriptions = '/prescriptions';
}
