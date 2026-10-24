import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/rdv_models.dart';
import '../../domain/rdv_regles.dart';

/// Petit badge icône + texte (jamais la couleur seule).
class RdvBadge extends StatelessWidget {
  const RdvBadge({
    super.key,
    required this.libelle,
    required this.icon,
    required this.couleur,
  });

  final String libelle;
  final IconData icon;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: couleur),
          const SizedBox(width: 4),
          Text(
            libelle,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: couleur),
          ),
        ],
      ),
    );
  }
}

class StatutBadge extends StatelessWidget {
  const StatutBadge({super.key, required this.statut});

  final StatutRdv statut;

  static Color couleur(StatutRdv s) {
    switch (s) {
      case StatutRdv.enAttente:
        return AppColors.warning;
      case StatutRdv.confirme:
        return AppColors.primary;
      case StatutRdv.enCours:
        return AppColors.purple;
      case StatutRdv.termine:
        return AppColors.success;
      case StatutRdv.annule:
        return AppColors.danger;
      case StatutRdv.absent:
        return AppColors.textSecondary;
    }
  }

  static IconData icone(StatutRdv s) {
    switch (s) {
      case StatutRdv.enAttente:
        return Icons.hourglass_top_rounded;
      case StatutRdv.confirme:
        return Icons.event_available_rounded;
      case StatutRdv.enCours:
        return Icons.play_circle_fill_rounded;
      case StatutRdv.termine:
        return Icons.check_circle_rounded;
      case StatutRdv.annule:
        return Icons.cancel_rounded;
      case StatutRdv.absent:
        return Icons.person_off_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RdvBadge(libelle: statut.libelle, icon: icone(statut), couleur: couleur(statut));
  }
}

class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type});

  final TypeRdv type;

  @override
  Widget build(BuildContext context) {
    final bool visio = type == TypeRdv.visio;
    return RdvBadge(
      libelle: visio ? 'Visio' : 'Présentiel',
      icon: visio ? Icons.videocam_rounded : Icons.local_hospital_rounded,
      couleur: visio ? AppColors.indigo : AppColors.secondary,
    );
  }
}

/// Affiché seulement si la priorité n'est pas normale (ou alerte récente).
class PrioriteBadge extends StatelessWidget {
  const PrioriteBadge({super.key, required this.priorite, this.alerte = false});

  final PrioriteRdv priorite;
  final bool alerte;

  @override
  Widget build(BuildContext context) {
    if (priorite == PrioriteRdv.urgente) {
      return const RdvBadge(
        libelle: 'Urgent',
        icon: Icons.emergency_rounded,
        couleur: AppColors.danger,
      );
    }
    if (priorite == PrioriteRdv.haute || alerte) {
      return const RdvBadge(
        libelle: 'Prioritaire',
        icon: Icons.priority_high_rounded,
        couleur: AppColors.warning,
      );
    }
    return const SizedBox.shrink();
  }
}

/// Carte d'un rendez-vous (listes et file d'attente).
class RdvCard extends StatelessWidget {
  const RdvCard({
    super.key,
    required this.detail,
    required this.onTap,
    this.afficherPatient = true,
    this.afficherMedecin = true,
    this.rang,
  });

  final RdvDetail detail;
  final VoidCallback onTap;
  final bool afficherPatient;
  final bool afficherMedecin;

  /// Position dans la file d'attente (1, 2, 3...).
  final int? rang;

  @override
  Widget build(BuildContext context) {
    final RendezVous r = detail.rdv;
    final bool actif = r.statut.estActif;
    final int? rang = this.rang;
    final String titre = afficherPatient ? detail.patientNom : detail.medecinNom;
    final String? sousTitre = afficherPatient && afficherMedecin
        ? detail.medecinNom
        : (afficherPatient ? null : detail.specialite);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: r.estUrgent && actif
                ? Border.all(color: AppColors.danger.withValues(alpha: 0.5), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 62,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: actif ? null : AppColors.surfaceGrey,
                  gradient: actif
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primaryDark, AppColors.primary],
                        )
                      : null,
                ),
                child: rang != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '#$rang',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            RdvFormat.heure(r.dateHeure),
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${r.dateHeure.day}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: actif ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            RdvFormat.mois(r.dateHeure),
                            style: TextStyle(
                              fontSize: 11,
                              color: actif ? Colors.white70 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    if (sousTitre != null)
                      Text(
                        sousTitre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '${RdvFormat.heure(r.dateHeure)} · ${r.motif}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatutBadge(statut: r.statut),
                        TypeBadge(type: r.type),
                        PrioriteBadge(priorite: r.priorite, alerte: detail.alerteRecente),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau des rappels J-1 / H-1.
class RappelsBanner extends StatelessWidget {
  const RappelsBanner({super.key, required this.rappels, required this.onTap});

  final List<Rappel> rappels;
  final ValueChanged<RdvDetail> onTap;

  @override
  Widget build(BuildContext context) {
    if (rappels.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        for (final Rappel r in rappels)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                onTap: () => onTap(r.detail),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.notifications_active_rounded, color: AppColors.warning),
                title: Text(r.libelle, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${RdvFormat.complet(r.detail.rdv.dateHeure)} · '
                  '${r.detail.rdv.type.libelle}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ),
      ],
    );
  }
}

/// Sélecteur à deux segments (À venir / Passés).
class Segments extends StatelessWidget {
  const Segments({
    super.key,
    required this.libelles,
    required this.index,
    required this.onChanged,
  });

  final List<String> libelles;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (int i = 0; i < libelles.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: i == index
                        ? const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    libelles[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: i == index ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Affiche une erreur métier (ou inattendue) dans un SnackBar.
void afficherErreur(BuildContext context, Object e) {
  final String message = e is RdvException ? e.message : 'Erreur : $e';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppColors.danger),
  );
}

void afficherInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
