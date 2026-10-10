import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../../../models/patient.dart';
import '../../../data/ordonnance_repository.dart';
import '../../../domain/models/ordonnance.dart';
import '../../../domain/models/vues_ordonnance.dart';
import '../../../domain/ordonnance_manager.dart';
import '../../../domain/traitement_manager.dart';
import '../../widgets/dialogues_ordonnance.dart';
import '../../widgets/elements_ui.dart';
import '../ordonnance_detail_screen.dart';

/// Ordonnances du médecin connecté : historique, filtres, nouvelle ordonnance.
class OrdonnancesTab extends StatefulWidget {
  const OrdonnancesTab({super.key, required this.medecinId});

  /// medecins.id du compte connecté (utilisateurs.ref_id).
  final int medecinId;

  @override
  State<OrdonnancesTab> createState() => _OrdonnancesTabState();
}

/// Filtres rapides par statut.
enum _Filtre {
  toutes('Toutes', null),
  brouillons('Brouillons', [StatutOrdonnance.brouillon]),
  enCours('En cours', [StatutOrdonnance.validee, StatutOrdonnance.partiellementDelivree]),
  delivrees('Délivrées', [StatutOrdonnance.delivree]),
  closes('Annulées / expirées', [StatutOrdonnance.annulee, StatutOrdonnance.expiree]);

  const _Filtre(this.libelle, this.statuts);

  final String libelle;
  final List<StatutOrdonnance>? statuts;
}

/// Période d'émission.
enum _Periode {
  tout('Toutes les dates', null),
  semaine('7 derniers jours', 7),
  mois('30 derniers jours', 30),
  trimestre('3 derniers mois', 90);

  const _Periode(this.libelle, this.jours);

  final String libelle;
  final int? jours;
}

class _OrdonnancesTabState extends State<OrdonnancesTab> {
  final OrdonnanceRepository _repo = OrdonnanceRepository();
  final OrdonnanceManager _manager = OrdonnanceManager();
  final TraitementManager _traitement = TraitementManager();

  List<OrdonnanceResume> _liste = [];
  List<AlerteObservance> _alertes = [];
  bool _chargement = true;
  String _texte = '';
  _Filtre _filtre = _Filtre.toutes;
  _Periode _periode = _Periode.tout;
  int _requete = 0;

  @override
  void initState() {
    super.initState();
    _charger();
    _chargerAlertes();
  }

  /// Patients sous 80 % d'observance (notification du module au médecin).
  Future<void> _chargerAlertes() async {
    final List<AlerteObservance> res = await _traitement.alertesObservance(widget.medecinId);
    if (mounted) {
      setState(() => _alertes = res);
    }
  }

  String _texteAlertes() {
    final List<String> noms = [];
    for (final AlerteObservance a in _alertes) {
      noms.add('${a.patientNom} (${a.observance.round()} %)');
    }
    return noms.join(', ');
  }

  Future<void> _charger() async {
    final int requete = ++_requete;
    final int? jours = _periode.jours;
    final List<OrdonnanceResume> res = await _repo.listerResumes(
      medecinId: widget.medecinId,
      statuts: _filtre.statuts,
      du: jours == null ? null : DateTime.now().subtract(Duration(days: jours)),
      texte: _texte,
    );
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _liste = res;
      _chargement = false;
    });
  }

  Future<void> _ouvrir(int ordonnanceId) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => OrdonnanceDetailScreen(ordonnanceId: ordonnanceId)),
    );
    _charger();
  }

  Future<void> _nouvelle() async {
    final Patient? patient = await choisirPatient(context, widget.medecinId);
    final int? patientId = patient?.id;
    if (patientId == null) {
      return;
    }
    final int id = await _manager.creerBrouillon(patientId: patientId, medecinId: widget.medecinId);
    if (!mounted) {
      return;
    }
    _ouvrir(id);
  }

  Future<void> _choisirPeriode() async {
    final _Periode? choix = await showModalBottomSheet<_Periode>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final _Periode p in _Periode.values)
                ListTile(
                  leading: Icon(
                    p == _periode ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: AppColors.primary,
                  ),
                  title: Text(p.libelle),
                  onTap: () => Navigator.pop(ctx, p),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (choix != null) {
      setState(() => _periode = choix);
      _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          EnTetePage(
            surtitre: 'Prescriptions',
            titre: 'Mes ordonnances',
            trailing: BoutonAjout(tooltip: 'Nouvelle ordonnance', onPressed: _nouvelle),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SearchField(
              hint: 'Patient ou numéro',
              onChanged: (String v) {
                _texte = v;
                _charger();
              },
              onFilterTap: _choisirPeriode,
              nbFiltres: _periode == _Periode.tout ? 0 : 1,
            ),
          ),
          if (_alertes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Observance sous 80 % : ${_texteAlertes()}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              children: [
                for (final _Filtre f in _Filtre.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.libelle),
                      selected: _filtre == f,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _filtre == f ? Colors.white : AppColors.textPrimary,
                      ),
                      onSelected: (_) {
                        setState(() => _filtre = f);
                        _charger();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _liste.isEmpty
                    ? const EmptyState(
                        icon: Icons.description_outlined,
                        message: 'Aucune ordonnance.\nTouchez + pour en rédiger une.',
                      )
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                          itemCount: _liste.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int i) {
                            final OrdonnanceResume r = _liste[i];
                            return CarteOrdonnance(
                              resume: r,
                              onTap: () => _ouvrir(r.ordonnance.id!),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'une ordonnance dans une liste.
class CarteOrdonnance extends StatelessWidget {
  const CarteOrdonnance({super.key, required this.resume, this.onTap});

  final OrdonnanceResume resume;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Ordonnance o = resume.ordonnance;
    final int nb = resume.nbLignes;

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
                  CircleAvatar(
                    backgroundColor: StyleStatut.couleur(o.statut).withValues(alpha: 0.12),
                    child: Icon(Icons.description_outlined, color: StyleStatut.couleur(o.statut)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resume.patientNom,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          o.numero,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  StyleStatut.badge(o.statut),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  InfoLigne(
                    icon: Icons.event_outlined,
                    texte: 'Émise le ${Formatters.date(o.dateEmission)}',
                  ),
                  InfoLigne(
                    icon: Icons.medication_outlined,
                    texte: '$nb médicament${nb > 1 ? 's' : ''}',
                  ),
                  if (o.nbRenouvellements > 0)
                    InfoLigne(
                      icon: Icons.autorenew_rounded,
                      texte: '${o.nbRenouvellements} renouvellement${o.nbRenouvellements > 1 ? 's' : ''}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
