import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_banner.dart';
import '../../../data/ordonnance_repository.dart';
import '../../../domain/models/contrat_assurance.dart';
import '../../../domain/models/ordonnance.dart';
import '../../../domain/models/vues_ordonnance.dart';
import '../../../domain/models/vues_remboursement.dart';
import '../../../domain/prescriptions_exception.dart';
import '../../../domain/remboursement_manager.dart';
import '../../widgets/carte_dossier.dart';
import '../../widgets/elements_ui.dart';
import '../../widgets/graphiques.dart';
import '../dossier_detail_screen.dart';

/// Patient : contrats et plafond, ordonnances à déclarer, dossiers.
class RemboursementsTab extends StatefulWidget {
  const RemboursementsTab({super.key, required this.patientId});

  final int patientId;

  @override
  State<RemboursementsTab> createState() => _RemboursementsTabState();
}

class _RemboursementsTabState extends State<RemboursementsTab> {
  final RemboursementManager _manager = RemboursementManager();
  final OrdonnanceRepository _ordonnances = OrdonnanceRepository();

  List<ContratDetail> _contrats = [];
  List<OrdonnanceResume> _aDeclarer = [];
  List<DossierResume> _dossiers = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final List<ContratDetail> contrats = await _manager.contratsDuPatient(widget.patientId);
    final List<DossierResume> dossiers = await _manager.dossiers(patientId: widget.patientId);
    final List<OrdonnanceResume> aDeclarer = [];
    for (final OrdonnanceResume r in await _ordonnances.listerResumes(
      patientId: widget.patientId,
      statuts: const [StatutOrdonnance.delivree, StatutOrdonnance.partiellementDelivree],
    )) {
      if (await _manager.dossierDe(r.ordonnance.id!) == null) {
        aDeclarer.add(r);
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _contrats = contrats;
      _dossiers = dossiers;
      _aDeclarer = aDeclarer;
      _chargement = false;
    });
  }

  Future<void> _ouvrir(int dossierId) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => DossierDetailScreen(dossierId: dossierId, admin: false)),
    );
    _charger();
  }

  Future<void> _creer(Ordonnance o) async {
    setState(() => _erreur = null);
    try {
      final int id = await _manager.creerDossier(o);
      if (!mounted) {
        return;
      }
      await _ouvrir(id);
    } on PrescriptionsException catch (e) {
      if (mounted) {
        setState(() => _erreur = e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
          children: [
            const EnTetePage(surtitre: 'CNAM et mutuelle', titre: 'Remboursements'),
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
                    const _Titre('Mes contrats'),
                    if (_contrats.isEmpty)
                      const Text('Aucun contrat : adressez-vous à l’accueil de l’hôpital.')
                    else
                      for (final ContratDetail c in _contrats)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CarteContrat(contrat: c),
                        ),
                    const SizedBox(height: 12),
                    if (_erreur != null) ...[
                      ErrorBanner(message: _erreur!),
                      const SizedBox(height: 12),
                    ],
                    if (_aDeclarer.isNotEmpty) ...[
                      const _Titre('À déclarer'),
                      for (final OrdonnanceResume r in _aDeclarer)
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                            title: Text(r.ordonnance.numero),
                            subtitle: Text('${r.medecinNom} · ${r.ordonnance.statut.libelle}'),
                            trailing: FilledButton(
                              onPressed: () => _creer(r.ordonnance),
                              child: const Text('Créer le dossier'),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    _Titre('Mes dossiers (${_dossiers.length})'),
                    if (_dossiers.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        message: 'Aucun dossier de remboursement',
                      )
                    else
                      for (final DossierResume d in _dossiers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CarteDossier(resume: d, onTap: () => _ouvrir(d.dossier.id!)),
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

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(texte, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
    );
  }
}

/// Carte d'un contrat : assurance, adhérent, APCI, jauge du plafond.
class CarteContrat extends StatelessWidget {
  const CarteContrat({super.key, required this.contrat, this.onTap});

  final ContratDetail contrat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ContratAssurance c = contrat.contrat;
    final FiliereCnam? filiere = c.filiere;
    return Opacity(
      opacity: contrat.actif ? 1 : 0.6,
      child: Card(
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
                      child: Text(
                        contrat.assurance.nom,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (c.apci)
                      BadgeStatut(
                        libelle: 'APCI ${c.codeApci ?? ''}',
                        icon: Icons.favorite_rounded,
                        couleur: AppColors.danger,
                      ),
                    if (!contrat.actif)
                      const BadgeStatut(
                        libelle: 'Résilié',
                        icon: Icons.event_busy_rounded,
                        couleur: AppColors.textSecondary,
                      ),
                  ],
                ),
                Text(
                  'Adhérent ${c.numeroAdherent} · ${c.beneficiaire.libelle}'
                  '${filiere == null ? '' : ' · ${filiere.libelle}'}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                if (contrat.assurance.estObligatoire) ...[
                  const SizedBox(height: 10),
                  JaugePlafond(contrat: contrat),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
