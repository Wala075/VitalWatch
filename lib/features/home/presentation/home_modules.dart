import 'package:flutter/material.dart';

import '../../../core/routing/app_routes.dart';

class HomeModule {
  const HomeModule(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

const List<HomeModule> homeModules = [
  HomeModule('Services & Personnel', Icons.badge, AppRoutes.staff),
  HomeModule('Patients & Suivi vital', Icons.monitor_heart,
      AppRoutes.patientMonitoring),
  HomeModule('Ambulances & Interventions', Icons.local_hospital,
      AppRoutes.ambulanceDispatch),
  HomeModule('Rendez-vous & Téléconsultation', Icons.event,
      AppRoutes.appointments),
  HomeModule('Ordonnances & Traitements', Icons.medication,
      AppRoutes.prescriptions),
];
