import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_view.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      title: 'Rendez-vous & Téléconsultation',
      icon: Icons.event,
    );
  }
}
