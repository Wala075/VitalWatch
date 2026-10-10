import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../domain/models/prise.dart';
import '../../../domain/models/vues_traitement.dart';
import '../../../domain/ordonnance_manager.dart';
import '../../../domain/planning_prises.dart';
import '../../../domain/prescriptions_exception.dart';
import '../../../domain/traitement_manager.dart';
import '../../widgets/elements_ui.dart';
import '../../widgets/graphiques.dart';

/// Patient : planning du jour (cocher les prises), observance sur 7 jours,
/// fin de stock et renouvellement.
class AujourdhuiTab extends StatefulWidget {
  const AujourdhuiTab({super.key, required this.patientId});

  final int patientId;

  @override
  State<AujourdhuiTab> createState() => _AujourdhuiTabState();
}

class _AujourdhuiTabState extends State<AujourdhuiTab> {
  final TraitementManager _manager = TraitementManager();
  final OrdonnanceManager _ordonnances = OrdonnanceManager();

  DateTime _jour = DateTime.now();
  List<PrisePlanifiee> _prises = [];
  List<ObservanceJour> _observance = [];
  List<StockTraitement> _stocks = [];
  double? _taux;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final List<PrisePlanifiee> prises = await _manager.planningDuJour(widget.patientId, _jour);
    final List<ObservanceJour> observance = await _manager.observanceParJour(widget.patientId);
    final List<StockTraitement> stocks = await _manager.stocks(widget.patientId);
    final double? taux = await _manager.observance(widget.patientId);
    if (!mounted) {
      return;
    }
    setState(() {
      _prises = prises;
      _observance = observance;
      _stocks = stocks;
      _taux = taux;
      _chargement = false;
    });
  }

  Future<void> _cocher(PrisePlanifiee p, StatutPrise statut) async {
    await _manager.cocher(p.prise.id!, statut);
    _charger();
  }

  Future<void> _renouveler(StockTraitement s) async {
    final ScaffoldMessengerState messages = ScaffoldMessenger.of(context);
    try {
      await _ordonnances.renouveler(s.ordonnance);
      messages.showSnackBar(
        const SnackBar(content: Text('Ordonnance renouvelée : à retirer en pharmacie')),
      );
    } on PrescriptionsException catch (e) {
      messages.showSnackBar(SnackBar(content: Text(e.message)));
    }
    _charger();
  }

  void _changerJour(int decalage) {
    setState(() => _jour = _jour.add(Duration(days: decalage)));
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime aujourdhui = DateTime.now();
    final bool estAujourdhui = _jour.year == aujourdhui.year &&
        _jour.month == aujourdhui.month &&
        _jour.day == aujourdhui.day;
    final List<StockTraitement> alertes = [];
    for (final StockTraitement s in _stocks) {
      if (s.alerte) {
        alertes.add(s);
      }
    }
    final double? taux = _taux;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
          children: [
            const EnTetePage(surtitre: 'Mon traitement', titre: "Aujourd'hui"),
            if (_chargement)
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
                    // Fin de stock (métier 4).
                    for (final StockTraitement s in alertes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AlerteStock(
                          stock: s,
                          onRenouveler: OrdonnanceManager.estRenouvelable(s.ordonnance)
                              ? () => _renouveler(s)
                              : null,
                        ),
                      ),

                    // Planning du jour.
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Jour précédent',
                          onPressed: () => _changerJour(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            estAujourdhui ? "Prises d'aujourd'hui" : 'Prises du ${Formatters.date(_jour)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Jour suivant',
                          onPressed: () => _changerJour(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    if (_prises.isEmpty)
                      const EmptyState(
                        icon: Icons.event_available_outlined,
                        message: 'Aucune prise prévue ce jour-là',
                      )
                    else
                      for (final PrisePlanifiee p in _prises)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CartePrise(
                            prise: p,
                            onCocher: (StatutPrise s) => _cocher(p, s),
                          ),
                        ),
                    const SizedBox(height: 16),

                    // Observance (métier 3).
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Observance sur 7 jours',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(
                                  taux == null ? '–' : '${taux.round()} %',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: taux == null || taux >= TraitementManager.seuilObservance
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Prises faites ÷ prises prévues (passées)',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            BarresObservance(jours: _observance),
                            if (taux != null && taux < TraitementManager.seuilObservance)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Sous 80 % : votre médecin est prévenu.',
                                  style: TextStyle(fontSize: 13, color: AppColors.warning),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stock de chaque médicament.
                    if (_stocks.isNotEmpty) ...[
                      const Text(
                        'Mes médicaments',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      for (final StockTraitement s in _stocks)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              StyleCategorie.iconeForme(s.forme),
                              color: s.alerte ? AppColors.danger : AppColors.primary,
                            ),
                            title: Text(s.medicament),
                            subtitle: Text(
                              'Reste ${s.stockTexte} · environ ${s.joursRestants.floor()} jour(s)',
                            ),
                            trailing: Text(s.ordonnance.numero, style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CartePrise extends StatelessWidget {
  const _CartePrise({required this.prise, required this.onCocher});

  final PrisePlanifiee prise;
  final ValueChanged<StatutPrise> onCocher;

  @override
  Widget build(BuildContext context) {
    final Prise p = prise.prise;
    final DateTime maintenant = DateTime.now();
    final bool enRetard = p.statut == StatutPrise.prevue &&
        maintenant.isAfter(p.heurePrevue.add(TraitementManager.delaiRappel));
    final String heure =
        '${p.heurePrevue.hour.toString().padLeft(2, '0')}:${p.heurePrevue.minute.toString().padLeft(2, '0')}';
    final String? instructions = prise.instructions;

    Color couleur = AppColors.primary;
    if (p.statut == StatutPrise.prise) {
      couleur = AppColors.success;
    } else if (p.statut == StatutPrise.oubliee) {
      couleur = AppColors.textSecondary;
    } else if (enRetard) {
      couleur = AppColors.warning;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(heure, style: TextStyle(fontWeight: FontWeight.w800, color: couleur)),
                  Text(
                    PlanningPrises.libelles[_moment(p.heurePrevue.hour)] ?? '',
                    style: TextStyle(fontSize: 10, color: couleur),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prise.medicament, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(prise.quantite, style: const TextStyle(color: AppColors.textSecondary)),
                  if (instructions != null)
                    Text(
                      instructions,
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  if (enRetard)
                    const Text(
                      'Rappel : prise en retard',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning),
                    ),
                ],
              ),
            ),
            if (p.statut == StatutPrise.prevue) ...[
              IconButton(
                tooltip: 'Oubliée',
                onPressed: () => onCocher(StatutPrise.oubliee),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
              ),
              IconButton.filled(
                tooltip: 'Prise',
                onPressed: () => onCocher(StatutPrise.prise),
                style: IconButton.styleFrom(backgroundColor: AppColors.success),
                icon: const Icon(Icons.check_rounded, color: Colors.white),
              ),
            ] else
              BadgeStatut(
                libelle: p.statut.libelle,
                icon: p.statut == StatutPrise.prise ? Icons.check_circle_rounded : Icons.cancel_outlined,
                couleur: couleur,
              ),
          ],
        ),
      ),
    );
  }

  /// Moment correspondant à l'heure prévue.
  static String _moment(int heure) {
    for (final String m in PlanningPrises.moments) {
      if (PlanningPrises.heures[m] == heure) {
        return m;
      }
    }
    return '';
  }
}

class _AlerteStock extends StatelessWidget {
  const _AlerteStock({required this.stock, this.onRenouveler});

  final StockTraitement stock;
  final VoidCallback? onRenouveler;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? renouveler = onRenouveler;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stock.medicament} : bientôt épuisé',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger),
                ),
                Text(
                  'Reste ${stock.stockTexte}, environ ${stock.joursRestants.floor()} jour(s)'
                  '${renouveler == null ? '' : ' · ${stock.ordonnance.nbRenouvellements} renouvellement(s)'}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          if (renouveler != null)
            FilledButton(onPressed: renouveler, child: const Text('Renouveler')),
        ],
      ),
    );
  }
}
