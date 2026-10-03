import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/demo_data.dart';

/// Avatar de médecin : fond pastel, silhouette, initiales et croix.
class DoctorAvatar extends StatelessWidget {
  const DoctorAvatar({
    super.key,
    required this.medecin,
    this.taille = 56,
    this.rayon = 16,
  });

  final DemoDoctor medecin;
  final double taille;
  final double rayon;

  @override
  Widget build(BuildContext context) {
    final Color clair =
        Color.lerp(medecin.couleur, Colors.white, 0.55) ?? medecin.couleur;

    return ClipRRect(
      borderRadius: BorderRadius.circular(rayon),
      child: Container(
        width: taille,
        height: taille,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [clair, medecin.couleur],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -taille * 0.08,
              bottom: -taille * 0.14,
              child: Icon(
                Icons.person_rounded,
                size: taille * 0.95,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            Positioned(
              left: taille * 0.12,
              top: taille * 0.1,
              child: Text(
                medecin.initiales,
                style: TextStyle(
                  fontSize: taille * 0.3,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary.withValues(alpha: 0.8),
                ),
              ),
            ),
            Positioned(
              left: taille * 0.12,
              bottom: taille * 0.12,
              child: Container(
                padding: EdgeInsets.all(taille * 0.04),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: taille * 0.15,
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
