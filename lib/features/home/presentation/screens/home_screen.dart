import 'package:flutter/material.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/routing/app_routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<_ModuleItem> _modules = [
    _ModuleItem('Services & Personnel', Icons.badge, AppRoutes.staff),
    _ModuleItem('Patients & Suivi vital', Icons.monitor_heart,
        AppRoutes.patientMonitoring),
    _ModuleItem('Ambulances & Interventions', Icons.local_hospital,
        AppRoutes.ambulanceDispatch),
    _ModuleItem('Rendez-vous & Téléconsultation', Icons.event,
        AppRoutes.appointments),
    _ModuleItem('Ordonnances & Traitements', Icons.medication,
        AppRoutes.prescriptions),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'Connexion',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          for (final _ModuleItem m in _modules)
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, m.route),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(m.icon,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(m.label, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModuleItem {
  const _ModuleItem(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}
