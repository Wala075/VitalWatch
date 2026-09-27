import 'package:flutter/material.dart';

import '../../features/ambulance_dispatch/presentation/screens/ambulance_dispatch_screen.dart';
import '../../features/appointments/presentation/screens/appointments_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/patient_monitoring/presentation/screens/patient_monitoring_screen.dart';
import '../../features/prescriptions/presentation/screens/prescriptions_screen.dart';
import '../../features/staff_management/presentation/screens/staff_management_screen.dart';
import 'app_routes.dart';

/// Point d'intégration unique des routes (géré par le chef de projet).
class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case AppRoutes.home:
        page = const HomeScreen();
        break;
      case AppRoutes.login:
        page = const LoginScreen();
        break;
      case AppRoutes.staff:
        page = const StaffManagementScreen();
        break;
      case AppRoutes.patientMonitoring:
        page = const PatientMonitoringScreen();
        break;
      case AppRoutes.ambulanceDispatch:
        page = const AmbulanceDispatchScreen();
        break;
      case AppRoutes.appointments:
        page = const AppointmentsScreen();
        break;
      case AppRoutes.prescriptions:
        page = const PrescriptionsScreen();
        break;
      default:
        page = Scaffold(
          body: Center(child: Text('Route inconnue : ${settings.name}')),
        );
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
