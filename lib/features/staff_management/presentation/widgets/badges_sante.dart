import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/disponibilite.dart';
import '../../domain/sante_simulee.dart';
import 'info_chip.dart';

Color couleurNiveau(NiveauAlerte niveau) {
  switch (niveau) {
    case NiveauAlerte.stable:
      return AppColors.success;
    case NiveauAlerte.surveiller:
      return AppColors.warning;
    case NiveauAlerte.critique:
      return AppColors.danger;
  }
}

Color couleurEtat(EtatMedecin etat) {
  switch (etat) {
    case EtatMedecin.enService:
      return AppColors.success;
    case EtatMedecin.horsHoraires:
      return AppColors.textSecondary;
    case EtatMedecin.absent:
      return AppColors.danger;
  }
}

/// Niveau d'alerte d'un patient : Stable / À surveiller / Critique.
class NiveauBadge extends StatelessWidget {
  const NiveauBadge({super.key, required this.niveau});

  final NiveauAlerte niveau;

  @override
  Widget build(BuildContext context) {
    switch (niveau) {
      case NiveauAlerte.stable:
        return StatusBadge(
          libelle: 'Stable',
          icon: Icons.check_circle_rounded,
          couleur: couleurNiveau(niveau),
        );
      case NiveauAlerte.surveiller:
        return StatusBadge(
          libelle: 'À surveiller',
          icon: Icons.warning_amber_rounded,
          couleur: couleurNiveau(niveau),
        );
      case NiveauAlerte.critique:
        return StatusBadge(
          libelle: 'Critique',
          icon: Icons.error_rounded,
          couleur: couleurNiveau(niveau),
        );
    }
  }
}

/// Disponibilité d'un médecin : En service / Reprend… / En congé.
class EtatMedecinBadge extends StatelessWidget {
  const EtatMedecinBadge({
    super.key,
    required this.disponibilite,
    required this.maintenant,
  });

  final Disponibilite disponibilite;
  final DateTime maintenant;

  @override
  Widget build(BuildContext context) {
    final EtatMedecin etat = disponibilite.etat;
    IconData icon = Icons.schedule_rounded;
    if (etat == EtatMedecin.enService) {
      icon = Icons.check_circle_rounded;
    } else if (etat == EtatMedecin.absent) {
      icon = Icons.event_busy_rounded;
    }
    return StatusBadge(
      libelle: disponibilite.libelle(maintenant),
      icon: icon,
      couleur: couleurEtat(etat),
    );
  }
}
