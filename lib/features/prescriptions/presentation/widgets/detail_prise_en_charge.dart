import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/calcul_prise_en_charge.dart';
import '../../domain/formats_prescriptions.dart';

/// Tableau du calcul de prise en charge : montant, CNAM, mutuelle, reste.
class TableauPriseEnCharge extends StatelessWidget {
  const TableauPriseEnCharge({super.key, required this.detail});

  final DetailPriseEnCharge detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final DetailLigne l in detail.lignes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.libelle} × ${l.boites}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                _Ligne('Montant', FormatsPrescriptions.dt(l.montant)),
                _Ligne('Base remboursable', FormatsPrescriptions.dt(l.base)),
                _Ligne(
                  l.apci ? 'CNAM (APCI 100 %)' : 'CNAM (${FormatsPrescriptions.taux(l.taux)})',
                  '− ${FormatsPrescriptions.dt(l.partCnam)}',
                ),
                _Ligne('Mutuelle', '− ${FormatsPrescriptions.dt(l.partMutuelle)}'),
                _Ligne('Reste', FormatsPrescriptions.dt(l.resteACharge), gras: true),
              ],
            ),
          ),
        const Divider(),
        _Ligne('Total', FormatsPrescriptions.dt(detail.montant), gras: true),
        _Ligne('Pris en charge par la CNAM', FormatsPrescriptions.dt(detail.partCnam)),
        _Ligne('Pris en charge par la mutuelle', FormatsPrescriptions.dt(detail.partMutuelle)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Reste à votre charge',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                FormatsPrescriptions.dt(detail.resteACharge),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
        for (final String r in detail.remarques)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
      ],
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.libelle, this.valeur, {this.gras = false});

  final String libelle;
  final String valeur;
  final bool gras;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: 14,
      fontWeight: gras ? FontWeight.w800 : FontWeight.w400,
      color: gras ? AppColors.textPrimary : AppColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(libelle, style: style)),
          Text(valeur, style: style),
        ],
      ),
    );
  }
}

/// Feuille « Combien je vais payer ? » : calcul sans rien enregistrer.
Future<void> afficherSimulation(
  BuildContext context, {
  required String titre,
  required Future<DetailPriseEnCharge> calcul,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext ctx) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: FutureBuilder<DetailPriseEnCharge>(
            future: calcul,
            builder: (BuildContext ctx, AsyncSnapshot<DetailPriseEnCharge> s) {
              final DetailPriseEnCharge? detail = s.data;
              if (detail == null) {
                return Center(
                  child: s.hasError
                      ? Text('Calcul impossible : ${s.error}')
                      : const CircularProgressIndicator(),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(titre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text(
                    'Simulation sur les boîtes prescrites : rien n’est enregistré.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TableauPriseEnCharge(detail: detail),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
