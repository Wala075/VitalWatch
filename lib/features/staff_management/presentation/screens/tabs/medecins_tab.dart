import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_dropdown_field.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../../../models/medecin.dart';
import '../../../../../models/service.dart';
import '../../../../../models/utilisateur.dart';
import '../../../data/horaire_repository.dart';
import '../../../data/medecin_repository.dart';
import '../../../data/service_repository.dart';
import '../../../domain/disponibilite.dart';
import '../../../domain/staff_models.dart';
import '../../widgets/avatar_initiales.dart';
import '../../widgets/badges_sante.dart';
import '../../widgets/bouton_ajout.dart';
import '../../widgets/info_chip.dart';
import '../medecin_detail_screen.dart';
import '../medecin_form_screen.dart';

/// Liste des médecins avec leur disponibilité en temps réel.
/// Toucher un médecin ouvre sa fiche (horaires, charge, patients).
class MedecinsTab extends StatefulWidget {
  const MedecinsTab({super.key, required this.role});

  final Role role;

  @override
  State<MedecinsTab> createState() => _MedecinsTabState();
}

class _Ligne {
  const _Ligne(this.detail, this.creneaux, this.disponibilite);

  final MedecinDetail detail;
  final List<Creneau> creneaux;
  final Disponibilite disponibilite;
}

class _MedecinsTabState extends State<MedecinsTab> {
  final MedecinRepository _repo = MedecinRepository();
  final HoraireRepository _horaireRepo = HoraireRepository();
  final ServiceRepository _serviceRepo = ServiceRepository();

  List<MedecinDetail> _medecins = [];
  Map<int, List<Creneau>> _horaires = {};
  MedecinFiltre _filtre = const MedecinFiltre();

  /// Filtre rapide sur l'état (null = tous).
  EtatMedecin? _etat;
  bool _chargement = true;
  int _requete = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final int requete = ++_requete;
    final List<MedecinDetail> res = await _repo.rechercher(_filtre);
    final Map<int, List<Creneau>> horaires = await _horaireRepo.tous();
    if (!mounted || requete != _requete) return;
    setState(() {
      _medecins = res;
      _horaires = horaires;
      _chargement = false;
    });
  }

  Future<void> _ouvrirFiltres() async {
    final List<Service> services = await _serviceRepo.lister();
    if (!mounted) return;
    final MedecinFiltre? res = await showModalBottomSheet<MedecinFiltre>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FiltreSheet(initial: _filtre, services: services),
    );
    if (!mounted || res == null) return;
    setState(() => _filtre = res);
    _charger();
  }

  Future<void> _ajouter() async {
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MedecinFormScreen()),
    );
    if (modifie == true) _charger();
  }

  Future<void> _ouvrir(Medecin m) async {
    final int? id = m.id;
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedecinDetailScreen(medecinId: id, role: widget.role),
      ),
    );
    if (mounted) _charger();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime maintenant = DateTime.now();
    final List<_Ligne> lignes = [
      for (final MedecinDetail d in _medecins)
        _Ligne(
          d,
          _horaires[d.medecin.id] ?? const [],
          Disponibilite.calculer(
            d.medecin,
            _horaires[d.medecin.id] ?? const [],
            maintenant,
          ),
        ),
    ]..sort((a, b) => a.disponibilite.etat.index.compareTo(b.disponibilite.etat.index));

    int compter(EtatMedecin e) =>
        lignes.where((l) => l.disponibilite.etat == e).length;
    final List<_Ligne> visibles = _etat == null
        ? lignes
        : lignes.where((l) => l.disponibilite.etat == _etat).toList();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          PageTitle(
            surtitre: 'Équipe médicale',
            titre: 'Médecins',
            trailing: widget.role.gererMedecins
                ? BoutonAjout(tooltip: 'Ajouter un médecin', onPressed: _ajouter)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SearchField(
              hint: 'Nom, matricule, spécialité...',
              nbFiltres: _filtre.nbFiltresActifs,
              onFilterTap: _ouvrirFiltres,
              onChanged: (String v) {
                _filtre = _filtre.avecTexte(v);
                _charger();
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                FiltreRapide(
                  libelle: 'Tous',
                  nombre: lignes.length,
                  selectionne: _etat == null,
                  onTap: () => setState(() => _etat = null),
                ),
                const SizedBox(width: 8),
                FiltreRapide(
                  libelle: 'En service',
                  nombre: compter(EtatMedecin.enService),
                  selectionne: _etat == EtatMedecin.enService,
                  couleur: AppColors.success,
                  onTap: () => setState(() => _etat = EtatMedecin.enService),
                ),
                const SizedBox(width: 8),
                FiltreRapide(
                  libelle: 'Hors horaires',
                  nombre: compter(EtatMedecin.horsHoraires),
                  selectionne: _etat == EtatMedecin.horsHoraires,
                  couleur: AppColors.textSecondary,
                  onTap: () => setState(() => _etat = EtatMedecin.horsHoraires),
                ),
                const SizedBox(width: 8),
                FiltreRapide(
                  libelle: 'En congé',
                  nombre: compter(EtatMedecin.absent),
                  selectionne: _etat == EtatMedecin.absent,
                  couleur: AppColors.danger,
                  onTap: () => setState(() => _etat = EtatMedecin.absent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : visibles.isEmpty
                    ? const EmptyState(
                        icon: Icons.medical_services_outlined,
                        message: 'Aucun médecin trouvé',
                      )
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                          itemCount: visibles.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int i) {
                            final _Ligne l = visibles[i];
                            return _MedecinCard(
                              ligne: l,
                              maintenant: maintenant,
                              onTap: () => _ouvrir(l.detail.medecin),
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

class _MedecinCard extends StatelessWidget {
  const _MedecinCard({
    required this.ligne,
    required this.maintenant,
    required this.onTap,
  });

  final _Ligne ligne;
  final DateTime maintenant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Medecin m = ligne.detail.medecin;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AvatarInitiales(prenom: m.prenom, nom: m.nom, rayon: 26),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: couleurEtat(ligne.disponibilite.etat),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.nomComplet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${m.specialite} · ${ligne.detail.serviceNom ?? 'Sans service'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    EtatMedecinBadge(
                      disponibilite: ligne.disponibilite,
                      maintenant: maintenant,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        InfoChip(
                          icon: Icons.people_outline,
                          texte: '${ligne.detail.nbPatients} patient(s)',
                        ),
                        InfoChip(
                          icon: Icons.schedule_rounded,
                          texte: '${Horaire.heuresParSemaine(ligne.creneaux)} h / sem.',
                        ),
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

class _FiltreSheet extends StatefulWidget {
  const _FiltreSheet({required this.initial, required this.services});

  final MedecinFiltre initial;
  final List<Service> services;

  @override
  State<_FiltreSheet> createState() => _FiltreSheetState();
}

class _FiltreSheetState extends State<_FiltreSheet> {
  int? _serviceId;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.initial.serviceId;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filtrer les médecins',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          AppDropdownField<int?>(
            label: 'Service',
            icon: Icons.apartment,
            value: _serviceId,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Tous')),
              for (final Service s in widget.services)
                DropdownMenuItem<int?>(value: s.id, child: Text(s.nom)),
            ],
            onChanged: (int? v) => setState(() => _serviceId = v),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    MedecinFiltre(texte: widget.initial.texte),
                  ),
                  child: const Text('Réinitialiser'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    MedecinFiltre(
                      texte: widget.initial.texte,
                      serviceId: _serviceId,
                    ),
                  ),
                  child: const Text('Appliquer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
