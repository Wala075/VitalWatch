import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_view.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      title: 'Connexion',
      icon: Icons.lock,
      message: 'Authentification à implémenter',
    );
  }
}
