import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/stats_repository.dart';
import '../../../domain/formats_prescriptions.dart';
import '../../widgets/elements_ui.dart';
import '../../widgets/graphiques.dart';

/// Métier 11 : statistiques (toutes les ordonnances pour l'admin, les
/// siennes pour le médecin).
class StatsTab extends StatefulWidget {
  const StatsTab({super.key, this.medecinId});

  /// null : toutes les ordonnances (admin).
  final int? medecinId;

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  Statistiques? _stats;

  static const List<String> _mois = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final Statistiques s = await StatsRepository().calculer(medecinId: widget.medecinId);
    if (mounted) {
      setState(() => _stats = s);
    }
  }

  String _libelleMois(String cle) {
    final int? m = int.tryParse(cle.split('-').last);
    return m == null || m < 1 || m > 12 ? cle : _mois[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final Statistiques? s = _stats;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
          children: [
            EnTetePage(
              surtitre: widget.medecinId == null ? 'Toutes les ordonnances' : 'Mes ordonnances',
              titre: 'Statistiques',
            ),
            if (s == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TuileChiffre(
                            libelle: 'Économie génériques',
                            valeur: FormatsPrescriptions.dt(s.economieGeneriques),
                            icon: Icons.recycling_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TuileChiffre(
                            libelle: 'Délai moyen de réponse',
                            valeur: s.delaiMoyenJours == null ? '–' : '${s.delaiMoyenJours!.round()} j',
                            icon: Icons.schedule_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TuileChiffre(
                            libelle: 'Taux de refus',
                            valeur: '${(s.tauxRefus * 100).round()} %',
                            icon: Icons.block_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      titre: 'Dépenses mensuelles',
                      sousTitre: 'Montant des dossiers, 6 derniers mois (DT)',
                      child: BarresVerticales(
                        libelles: [for (final ValeurStat v in s.depensesMensuelles) _libelleMois(v.libelle)],
                        valeurs: [for (final ValeurStat v in s.depensesMensuelles) v.valeur],
                      ),
                    ),
                    _Section(
                      titre: 'Qui paie ?',
                      sousTitre: 'Dossiers acceptés, partiels et remboursés',
                      child: Column(
                        children: [
                          BarreHorizontale(
                            libelle: 'CNAM',
                            valeur: s.partCnam,
                            maximum: s.partCnam + s.partMutuelle + s.partPatient,
                            texte: FormatsPrescriptions.dt(s.partCnam),
                          ),
                          BarreHorizontale(
                            libelle: 'Mutuelle',
                            valeur: s.partMutuelle,
                            maximum: s.partCnam + s.partMutuelle + s.partPatient,
                            texte: FormatsPrescriptions.dt(s.partMutuelle),
                            couleur: AppColors.purple,
                          ),
                          BarreHorizontale(
                            libelle: 'Patients',
                            valeur: s.partPatient,
                            maximum: s.partCnam + s.partMutuelle + s.partPatient,
                            texte: FormatsPrescriptions.dt(s.partPatient),
                            couleur: AppColors.warning,
                          ),
                        ],
                      ),
                    ),
                    _Section(
                      titre: 'Dépenses par patient',
                      sousTitre: 'Top 5',
                      child: _Barres(valeurs: s.depensesParPatient, monnaie: true),
                    ),
                    _Section(
                      titre: 'Médicaments les plus coûteux',
                      sousTitre: 'Boîtes délivrées × prix public (top 5)',
                      child: _Barres(valeurs: s.topMedicaments, monnaie: true),
                    ),
                    _Section(
                      titre: 'Refus par motif',
                      sousTitre: '${s.nbRefuses} refus sur ${s.nbRepondus} réponses',
                      child: _Barres(valeurs: s.refusParMotif, monnaie: false, couleur: AppColors.danger),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.titre, required this.sousTitre, required this.child});

  final String titre;
  final String sousTitre;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(sousTitre, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Barres extends StatelessWidget {
  const _Barres({required this.valeurs, required this.monnaie, this.couleur = AppColors.primary});

  final List<ValeurStat> valeurs;
  final bool monnaie;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    if (valeurs.isEmpty) {
      return const Text('Pas encore de données', style: TextStyle(color: AppColors.textSecondary));
    }
    double max = 0;
    for (final ValeurStat v in valeurs) {
      if (v.valeur > max) {
        max = v.valeur;
      }
    }
    return Column(
      children: [
        for (final ValeurStat v in valeurs)
          BarreHorizontale(
            libelle: v.libelle,
            valeur: v.valeur,
            maximum: max,
            texte: monnaie ? FormatsPrescriptions.dt(v.valeur) : v.valeur.round().toString(),
            couleur: couleur,
          ),
      ],
    );
  }
}
