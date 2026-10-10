import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/formats_prescriptions.dart';
import '../../domain/models/vues_remboursement.dart';
import '../../domain/models/vues_traitement.dart';

/// Barres verticales de l'observance des 7 derniers jours.
class BarresObservance extends StatelessWidget {
  const BarresObservance({super.key, required this.jours});

  final List<ObservanceJour> jours;

  static const List<String> _initiales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final ObservanceJour j in jours)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      j.taux == null ? '–' : '${(j.taux! * 100).round()}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 8 + 80 * (j.taux ?? 0),
                      decoration: BoxDecoration(
                        color: j.taux == null
                            ? AppColors.surfaceGrey
                            : (j.taux! >= 0.8 ? AppColors.success : AppColors.warning),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _initiales[j.jour.weekday - 1],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Barre horizontale : libellé, valeur, proportion du maximum.
class BarreHorizontale extends StatelessWidget {
  const BarreHorizontale({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.maximum,
    required this.texte,
    this.couleur = AppColors.primary,
  });

  final String libelle;
  final double valeur;
  final double maximum;
  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final double part = maximum <= 0 ? 0 : (valeur / maximum).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(texte, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: part,
              minHeight: 10,
              color: couleur,
              backgroundColor: couleur.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barres verticales simples (dépenses par mois).
class BarresVerticales extends StatelessWidget {
  const BarresVerticales({super.key, required this.libelles, required this.valeurs});

  final List<String> libelles;
  final List<double> valeurs;

  @override
  Widget build(BuildContext context) {
    double max = 0;
    for (final double v in valeurs) {
      if (v > max) {
        max = v;
      }
    }
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < valeurs.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      valeurs[i] == 0 ? '' : valeurs[i].round().toString(),
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 4 + (max <= 0 ? 0 : 100 * valeurs[i] / max),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      libelles[i],
                      style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Jauge du plafond annuel d'un contrat (alerte à 80 %).
class JaugePlafond extends StatelessWidget {
  const JaugePlafond({super.key, required this.contrat});

  final ContratDetail contrat;

  @override
  Widget build(BuildContext context) {
    final double? ratio = contrat.ratio;
    final double? plafond = contrat.plafond;
    if (ratio == null || plafond == null) {
      return Text(
        'Sans plafond · ${FormatsPrescriptions.dt(contrat.consomme)} remboursés cette année',
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      );
    }
    final Color couleur = contrat.alerte ? AppColors.danger : AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Plafond annuel : ${FormatsPrescriptions.dt(contrat.consomme)} / ${FormatsPrescriptions.dt(plafond)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            Text(
              '${(ratio * 100).round()} %',
              style: TextStyle(fontWeight: FontWeight.w800, color: couleur),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            color: couleur,
            backgroundColor: couleur.withValues(alpha: 0.12),
          ),
        ),
        if (contrat.alerte) ...[
          const SizedBox(height: 6),
          const Text(
            'Plus de 80 % du plafond consommé',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

/// Grande valeur avec libellé (statistiques).
class TuileChiffre extends StatelessWidget {
  const TuileChiffre({super.key, required this.libelle, required this.valeur, this.icon});

  final String libelle;
  final String valeur;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final IconData? i = icon;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i != null) Icon(i, color: AppColors.primary, size: 20),
            const SizedBox(height: 6),
            Text(
              valeur,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            Text(libelle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
