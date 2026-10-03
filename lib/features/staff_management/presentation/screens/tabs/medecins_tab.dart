import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_dropdown_field.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../../../models/medecin.dart';
import '../../../../../models/service.dart';
import '../../../../../models/utilisateur.dart';
import '../../../data/medecin_repository.dart';
import '../../../data/service_repository.dart';
import '../../../domain/staff_models.dart';
import '../../widgets/avatar_initiales.dart';
import '../../widgets/info_chip.dart';
import '../medecin_form_screen.dart';

class MedecinsTab extends StatefulWidget {
  const MedecinsTab({super.key, required this.role});

  final Role role;

  @override
  State<MedecinsTab> createState() => _MedecinsTabState();
}

class _MedecinsTabState extends State<MedecinsTab> {
  final MedecinRepository _repo = MedecinRepository();
  final ServiceRepository _serviceRepo = ServiceRepository();

  List<MedecinDetail> _medecins = [];
  MedecinFiltre _filtre = const MedecinFiltre();
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
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _medecins = res;
      _chargement = false;
    });
  }

  Future<void> _ouvrirFiltres() async {
    final List<Service> services = await _serviceRepo.lister();
    if (!mounted) {
      return;
    }
    final MedecinFiltre? res = await showModalBottomSheet<MedecinFiltre>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FiltreSheet(initial: _filtre, services: services),
    );
    if (res != null) {
      setState(() => _filtre = res);
      _charger();
    }
  }

  Future<void> _ouvrirFormulaire([Medecin? medecin]) async {
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MedecinFormScreen(medecin: medecin)),
    );
    if (modifie == true) {
      _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool gerer = widget.role.gererMedecins;

    return Scaffold(
      floatingActionButton: gerer
          ? FloatingActionButton.extended(
              heroTag: 'fab_medecins',
              onPressed: () => _ouvrirFormulaire(),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Médecin'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _medecins.isEmpty
                    ? const EmptyState(
                        icon: Icons.medical_services_outlined,
                        message: 'Aucun médecin trouvé',
                      )
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: _medecins.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int i) {
                            final MedecinDetail d = _medecins[i];
                            return _MedecinCard(
                              detail: d,
                              onTap: gerer
                                  ? () => _ouvrirFormulaire(d.medecin)
                                  : null,
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
  const _MedecinCard({required this.detail, this.onTap});

  final MedecinDetail detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Medecin m = detail.medecin;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AvatarInitiales(prenom: m.prenom, nom: m.nom),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.nomComplet,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${m.specialite} · ${detail.serviceNom ?? 'Sans service'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        InfoChip(icon: Icons.badge_outlined, texte: m.matricule),
                        InfoChip(
                          icon: Icons.people_outline,
                          texte: '${detail.nbPatients} patient(s)',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              m.disponible
                  ? const StatusBadge(
                      libelle: 'Dispo',
                      icon: Icons.check_circle,
                      couleur: AppColors.success,
                    )
                  : const StatusBadge(
                      libelle: 'Indispo',
                      icon: Icons.pause_circle,
                      couleur: AppColors.textSecondary,
                    ),
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
  bool? _disponible;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.initial.serviceId;
    _disponible = widget.initial.disponible;
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
          const SizedBox(height: 16),
          const Text('Disponibilité'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tous'),
                selected: _disponible == null,
                onSelected: (_) => setState(() => _disponible = null),
              ),
              ChoiceChip(
                label: const Text('Disponibles'),
                selected: _disponible == true,
                onSelected: (_) => setState(() => _disponible = true),
              ),
              ChoiceChip(
                label: const Text('Indisponibles'),
                selected: _disponible == false,
                onSelected: (_) => setState(() => _disponible = false),
              ),
            ],
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
                      disponible: _disponible,
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
