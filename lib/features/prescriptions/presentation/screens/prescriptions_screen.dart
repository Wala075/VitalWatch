import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_view.dart';

class PrescriptionsScreen extends StatelessWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      title: 'Ordonnances & Traitements',
      icon: Icons.medication,
    );
  }
}
