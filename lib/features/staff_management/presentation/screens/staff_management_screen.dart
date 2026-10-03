import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/placeholder_view.dart';
import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import 'tabs/medecins_tab.dart';
import 'tabs/patients_tab.dart';
import 'tabs/services_tab.dart';
import 'tabs/stats_tab.dart';

/// MODULE 1 — Services & Personnel.
class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Role? role = Session.utilisateur?.role;
    if (role == null || !role.accesPersonnel) {
      return const PlaceholderView(
        title: 'Services & Personnel',
        icon: Icons.lock_outline,
        message: 'Accès réservé au personnel',
      );
    }

    final List<Tab> onglets = [
      const Tab(icon: Icon(Icons.apartment), text: 'Services'),
      const Tab(icon: Icon(Icons.medical_services_outlined), text: 'Médecins'),
      const Tab(icon: Icon(Icons.people_outline), text: 'Patients'),
      if (role.voirStats)
        const Tab(icon: Icon(Icons.insights), text: 'Stats'),
    ];
    final List<Widget> vues = [
      ServicesTab(role: role),
      MedecinsTab(role: role),
      PatientsTab(role: role),
      if (role.voirStats) const StatsTab(),
    ];

    return DefaultTabController(
      length: onglets.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Services & Personnel'),
          bottom: TabBar(
            tabs: onglets,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
        ),
        body: TabBarView(children: vues),
      ),
    );
  }
}
