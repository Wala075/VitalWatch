import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/dossier_remboursement.dart';
import '../../domain/models/medicament.dart';
import '../../domain/models/ordonnance.dart';

/// En-tête d'onglet : retour + « surtitre » / « Titre » + action à droite.
class EnTetePage extends StatelessWidget {
  const EnTetePage({
    super.key,
    required this.surtitre,
    required this.titre,
    this.trailing,
  });

  final String surtitre;
  final String titre;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Widget? fin = trailing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 14),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surtitre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 30,
                    height: 1.15,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (fin != null) fin,
        ],
      ),
    );
  }
}

/// Bouton rond « + » à droite du titre (la barre flottante cache un FAB).
class BoutonAjout extends StatelessWidget {
  const BoutonAjout({super.key, required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        fixedSize: const Size(48, 48),
      ),
      icon: const Icon(Icons.add_rounded, size: 26),
    );
  }
}

/// Bloc de formulaire avec titre et icône.
class SectionFormulaire extends StatelessWidget {
  const SectionFormulaire({
    super.key,
    required this.titre,
    required this.icon,
    required this.children,
    this.aide,
  });

  final String titre;
  final IconData icon;
  final List<Widget> children;

  /// Petite explication sous le titre.
  final String? aide;

  @override
  Widget build(BuildContext context) {
    final List<Widget> contenu = [];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        contenu.add(const SizedBox(height: 14));
      }
      contenu.add(children[i]);
    }
    final String? texteAide = aide;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (texteAide != null) ...[
              const SizedBox(height: 6),
              Text(
                texteAide,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            ...contenu,
          ],
        ),
      ),
    );
  }
}

/// Badge d'état : icône + libellé, jamais la couleur seule.
class BadgeStatut extends StatelessWidget {
  const BadgeStatut({
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: couleur),
          const SizedBox(width: 4),
          Text(
            libelle,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: couleur),
          ),
        ],
      ),
    );
  }
}

/// Petite étiquette icône + texte (ex. « Réponse sous 30 j »).
class InfoLigne extends StatelessWidget {
  const InfoLigne({super.key, required this.icon, required this.texte});

  final IconData icon;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(texte, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }
}

/// Couleur et icône de chaque catégorie de remboursement.
class StyleCategorie {
  StyleCategorie._();

  static Color couleur(CategorieMedicament c) {
    switch (c) {
      case CategorieMedicament.vital:
        return AppColors.danger;
      case CategorieMedicament.essentiel:
        return AppColors.primary;
      case CategorieMedicament.intermediaire:
        return AppColors.warning;
      case CategorieMedicament.nonRemboursable:
        return AppColors.textSecondary;
    }
  }

  static IconData icone(CategorieMedicament c) {
    switch (c) {
      case CategorieMedicament.vital:
        return Icons.favorite_rounded;
      case CategorieMedicament.essentiel:
        return Icons.verified_rounded;
      case CategorieMedicament.intermediaire:
        return Icons.adjust_rounded;
      case CategorieMedicament.nonRemboursable:
        return Icons.money_off_rounded;
    }
  }

  static BadgeStatut badge(CategorieMedicament c) {
    return BadgeStatut(libelle: c.libelle, icon: icone(c), couleur: couleur(c));
  }

  /// Icône selon la forme du médicament.
  static IconData iconeForme(String forme) {
    final String f = forme.toLowerCase();
    if (f.contains('sirop') || f.contains('solution') || f.contains('gouttes')) {
      return Icons.water_drop_outlined;
    }
    if (f.contains('inject') || f.contains('stylo')) {
      return Icons.vaccines_outlined;
    }
    if (f.contains('aérosol') || f.contains('inhal')) {
      return Icons.air_rounded;
    }
    return Icons.medication_outlined;
  }
}

/// Couleur, icône et badge de chaque statut d'ordonnance.
class StyleStatut {
  StyleStatut._();

  static Color couleur(StatutOrdonnance s) {
    switch (s) {
      case StatutOrdonnance.brouillon:
        return AppColors.textSecondary;
      case StatutOrdonnance.validee:
        return AppColors.primary;
      case StatutOrdonnance.partiellementDelivree:
        return AppColors.warning;
      case StatutOrdonnance.delivree:
        return AppColors.success;
      case StatutOrdonnance.expiree:
        return AppColors.textSecondary;
      case StatutOrdonnance.annulee:
        return AppColors.danger;
    }
  }

  static IconData icone(StatutOrdonnance s) {
    switch (s) {
      case StatutOrdonnance.brouillon:
        return Icons.edit_note_rounded;
      case StatutOrdonnance.validee:
        return Icons.verified_rounded;
      case StatutOrdonnance.partiellementDelivree:
        return Icons.hourglass_bottom_rounded;
      case StatutOrdonnance.delivree:
        return Icons.check_circle_rounded;
      case StatutOrdonnance.expiree:
        return Icons.event_busy_rounded;
      case StatutOrdonnance.annulee:
        return Icons.cancel_rounded;
    }
  }

  static BadgeStatut badge(StatutOrdonnance s) {
    return BadgeStatut(libelle: s.libelle, icon: icone(s), couleur: couleur(s));
  }
}

/// Couleur, icône et badge de chaque statut de dossier de remboursement.
class StyleDossier {
  StyleDossier._();

  static Color couleur(StatutDossier s) {
    switch (s) {
      case StatutDossier.brouillon:
        return AppColors.textSecondary;
      case StatutDossier.soumis:
      case StatutDossier.enCours:
        return AppColors.warning;
      case StatutDossier.accepte:
      case StatutDossier.partiel:
        return AppColors.primary;
      case StatutDossier.refuse:
        return AppColors.danger;
      case StatutDossier.rembourse:
        return AppColors.success;
    }
  }

  static IconData icone(StatutDossier s) {
    switch (s) {
      case StatutDossier.brouillon:
        return Icons.edit_note_rounded;
      case StatutDossier.soumis:
        return Icons.outbox_rounded;
      case StatutDossier.enCours:
        return Icons.hourglass_top_rounded;
      case StatutDossier.accepte:
        return Icons.thumb_up_alt_outlined;
      case StatutDossier.partiel:
        return Icons.incomplete_circle_rounded;
      case StatutDossier.refuse:
        return Icons.block_rounded;
      case StatutDossier.rembourse:
        return Icons.savings_rounded;
    }
  }

  static BadgeStatut badge(StatutDossier s) {
    return BadgeStatut(libelle: s.libelle, icon: icone(s), couleur: couleur(s));
  }
}
