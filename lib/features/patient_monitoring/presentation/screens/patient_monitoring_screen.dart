import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_view.dart';

class PatientMonitoringScreen extends StatelessWidget {
  const PatientMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      title: 'Patients & Suivi vital',
      icon: Icons.monitor_heart,
    );
  }
}
