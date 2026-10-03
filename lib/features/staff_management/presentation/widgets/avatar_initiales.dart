import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Avatar rond avec les initiales (prénom + nom).
class AvatarInitiales extends StatelessWidget {
  const AvatarInitiales({
    super.key,
    required this.prenom,
    required this.nom,
    this.couleur = AppColors.primary,
    this.rayon = 22,
  });

  final String prenom;
  final String nom;
  final Color couleur;
  final double rayon;

  String get _initiales {
    final String p = prenom.trim().isEmpty ? '' : prenom.trim()[0];
    final String n = nom.trim().isEmpty ? '' : nom.trim()[0];
    final String i = (p + n).toUpperCase();
    return i.isEmpty ? '?' : i;
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: rayon,
      backgroundColor: couleur.withValues(alpha: 0.12),
      child: Text(
        _initiales,
        style: TextStyle(
          color: couleur,
          fontWeight: FontWeight.bold,
          fontSize: rayon * 0.7,
        ),
      ),
    );
  }
}
