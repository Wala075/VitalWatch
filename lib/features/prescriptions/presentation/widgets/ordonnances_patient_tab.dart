import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/ordonnance_repository.dart';
import '../../domain/models/vues_ordonnance.dart';
import '../../domain/models/vues_remboursement.dart';
import '../../domain/remboursement_manager.dart';
import '../screens/contrat_form_screen.dart';
import '../screens/dossier_detail_screen.dart';
import '../screens/ordonnance_detail_screen.dart';
import '../screens/tabs/ordonnances_tab.dart';
import '../screens/tabs/remboursements_tab.dart';
import 'carte_dossier.dart';

/// Onglet « Ordonnances » de la fiche patient (gestion Patients d'Abir) :
/// traitements en cours, ordonnances, contrats et dossiers du patient.
/// Lecture seule, sauf les contrats si [gererContrats] (admin).
class OrdonnancesPatientTab extends StatefulWidget {
  const OrdonnancesPatientTab({
    super.key,
    required this.patientId,
    this.gererContrats = false,
    this.traiterDossiers = false,
  });

  final int patientId;
  final bool gererContrats;
  final bool traiterDossiers;

  @override
  State<OrdonnancesPatientTab> createState() => _OrdonnancesPatientTabState();
}

class _OrdonnancesPatientTabState extends State<OrdonnancesPatientTab> {
  final OrdonnanceRepository _ordonnances = OrdonnanceRepository();
  final RemboursementManager _remboursement = RemboursementManager();

  List<TraitementActif> _traitements = [];
  List<OrdonnanceResume> _liste = [];
  List<ContratDetail> _contrats = [];
  List<DossierResume> _dossiers = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final List<TraitementActif> traitements = await _ordonnances.traitementsActifs(widget.patientId);
    final List<OrdonnanceResume> liste = await _ordonnances.listerResumes(patientId: widget.patientId);
    final List<ContratDetail> contrats = await _remboursement.contratsDuPatient(widget.patientId);
    final List<DossierResume> dossiers = await _remboursement.dossiers(patientId: widget.patientId);
    if (!mounted) {
      return;
    }
    setState(() {
      _traitements = traitements;
      _liste = liste;
      _contrats = contrats;
      _dossiers = dossiers;
      _chargement = false;
    });
  }

  Future<void> _ouvrirPage(Widget page) async {
    await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => page));
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const _Titre('Traitements en cours'),
          if (_traitements.isEmpty)
            const _Vide('Aucun traitement en cours')
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final TraitementActif t in _traitements)
                    ListTile(
                      leading: const Icon(Icons.medication_outlined, color: AppColors.primary),
                      title: Text(t.medicament),
                      subtitle: Text('${t.dci} · ${t.numero} · ${t.medecinNom}'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: _Titre('Contrats')),
              if (widget.gererContrats)
                TextButton.icon(
                  onPressed: () => _ouvrirPage(ContratFormScreen(patientId: widget.patientId)),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter'),
                ),
            ],
          ),
          if (_contrats.isEmpty)
            const _Vide('Aucun contrat d’assurance')
          else
            for (final ContratDetail c in _contrats)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CarteContrat(
                  contrat: c,
                  onTap: widget.gererContrats
                      ? () => _ouvrirPage(ContratFormScreen(patientId: widget.patientId, contrat: c.contrat))
                      : null,
                ),
              ),
          const SizedBox(height: 16),
          _Titre('Ordonnances (${_liste.length})'),
          if (_liste.isEmpty)
            const _Vide('Aucune ordonnance')
          else
            for (final OrdonnanceResume r in _liste)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CarteOrdonnance(
                  resume: r,
                  onTap: () => _ouvrirPage(
                    OrdonnanceDetailScreen(ordonnanceId: r.ordonnance.id!, lectureSeule: true),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          _Titre('Dossiers de remboursement (${_dossiers.length})'),
          if (_dossiers.isEmpty)
            const _Vide('Aucun dossier')
          else
            for (final DossierResume d in _dossiers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CarteDossier(
                  resume: d,
                  onTap: widget.traiterDossiers
                      ? () => _ouvrirPage(DossierDetailScreen(dossierId: d.dossier.id!, admin: true))
                      : null,
                ),
              ),
        ],
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

class _Vide extends StatelessWidget {
  const _Vide(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(texte, style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}
