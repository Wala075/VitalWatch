import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/formats_prescriptions.dart';
import '../../domain/models/dossier_remboursement.dart';
import '../../domain/models/vues_remboursement.dart';
import 'elements_ui.dart';

/// Carte d'un dossier de remboursement dans une liste.
class CarteDossier extends StatelessWidget {
  const CarteDossier({super.key, required this.resume, this.onTap, this.afficherPatient = false});

  final DossierResume resume;
  final VoidCallback? onTap;
  final bool afficherPatient;

  @override
  Widget build(BuildContext context) {
    final DossierRemboursement d = resume.dossier;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          afficherPatient ? resume.patientNom : d.numero,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          afficherPatient
                              ? '${d.numero} · ${resume.ordonnanceNumero}'
                              : 'Ordonnance ${resume.ordonnanceNumero}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  StyleDossier.badge(d.statut),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  InfoLigne(icon: Icons.receipt_long_outlined, texte: FormatsPrescriptions.dt(d.montantTotal)),
                  InfoLigne(
                    icon: Icons.account_balance_outlined,
                    texte: 'CNAM ${FormatsPrescriptions.dt(d.partObligatoire)}',
                  ),
                  InfoLigne(
                    icon: d.restePaye ? Icons.check_circle_outline : Icons.person_outline,
                    texte: 'Reste ${FormatsPrescriptions.dt(d.resteACharge)}${d.restePaye ? ' (payé)' : ''}',
                  ),
                ],
              ),
              if (resume.enRetard)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: BadgeStatut(
                    libelle: 'Relance : délai dépassé',
                    icon: Icons.notification_important_rounded,
                    couleur: AppColors.warning,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
