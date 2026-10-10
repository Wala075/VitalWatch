import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/formats_prescriptions.dart';
import '../../domain/models/medicament.dart';
import '../../domain/substitution_generique.dart';

/// Équivalents moins chers (RxNorm + catalogue local) et économies.
/// [onChoisir] : le médecin remplace le médicament (null : consultation).
Future<void> afficherSubstitution(
  BuildContext context, {
  required Medicament medicament,
  int? patientId,
  int boites = 1,
  ValueChanged<Medicament>? onChoisir,
}) {
  final Future<PropositionSubstitution> recherche =
      SubstitutionGenerique().proposer(medicament, patientId: patientId, boites: boites);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext ctx) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: FutureBuilder<PropositionSubstitution>(
            future: recherche,
            builder: (BuildContext ctx, AsyncSnapshot<PropositionSubstitution> s) {
              final PropositionSubstitution? p = s.data;
              if (p == null) {
                return Center(
                  child: s.hasError
                      ? Text('Recherche impossible : ${s.error}')
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Interrogation de RxNorm…'),
                          ],
                        ),
                );
              }
              final String? remarque = p.remarque;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(
                    'Équivalents de ${medicament.libelle}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        p.rxcui == null ? Icons.cloud_off_rounded : Icons.verified_rounded,
                        size: 16,
                        color: p.rxcui == null ? AppColors.warning : AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p.rxcui == null
                              ? (remarque ?? 'RxNorm indisponible')
                              : 'RxNorm : ${SubstitutionGenerique.nomAnglais(medicament.dci)} '
                                  '(RxCUI ${p.rxcui})'
                                  '${p.dosageConfirme ? ' · dosage ${medicament.dosage} confirmé' : ''}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (p.equivalents.isEmpty)
                    const Text(
                      'Aucun équivalent moins cher dans le catalogue (même DCI, dosage et forme).',
                    )
                  else
                    for (final Equivalent e in p.equivalents)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(e.medicament.libelle),
                          subtitle: Text(
                            '${FormatsPrescriptions.dt(e.medicament.prixPublic)} la boîte'
                            '${e.medicament.generique ? ' · générique' : ''}\n'
                            'Économie patient : ${FormatsPrescriptions.dt(e.economiePatient)}'
                            '${patientId == null ? '' : ' · assurance : ${FormatsPrescriptions.dt(e.economieAssurance)}'}',
                          ),
                          isThreeLine: true,
                          trailing: onChoisir == null
                              ? null
                              : FilledButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    onChoisir(e.medicament);
                                  },
                                  child: const Text('Utiliser'),
                                ),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
