import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_view.dart';

class AmbulanceDispatchScreen extends StatelessWidget {
  const AmbulanceDispatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      title: 'Ambulances & Interventions',
      icon: Icons.local_hospital,
    );
  }
}
