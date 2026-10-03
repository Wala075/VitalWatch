import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_dropdown_field.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../../../models/patient.dart';
import '../../../../../models/service.dart';
import '../../../../../models/utilisateur.dart';
import '../../../data/patient_repository.dart';
import '../../../data/service_repository.dart';
import '../../../domain/staff_models.dart';
import '../../widgets/avatar_initiales.dart';
import '../../widgets/info_chip.dart';
import '../patient_form_screen.dart';

class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key, required this.role});

  final Role role;

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  final PatientRepository _repo = PatientRepository();
  final ServiceRepository _serviceRepo = ServiceRepository();

  List<PatientDetail> _patients = [];
  PatientFiltre _filtre = const PatientFiltre();
  bool _chargement = true;
  int _requete = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final int requete = ++_requete;
    final List<PatientDetail> res = await _repo.rechercher(_filtre);
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() {
      _patients = res;
      _chargement = false;
    });
  }

  Future<void> _ouvrirFiltres() async {
    final List<Service> services = await _serviceRepo.lister();
    if (!mounted) {
      return;
    }
    final PatientFiltre? res = await showModalBottomSheet<PatientFiltre>(
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

  Future<void> _ouvrirFormulaire([Patient? patient]) async {
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PatientFormScreen(
          patient: patient,
          peutSupprimer: widget.role.supprimerPatients,
        ),
      ),
    );
    if (modifie == true) {
      _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool gerer = widget.role.gererPatients;

    return Scaffold(
      floatingActionButton: gerer
          ? FloatingActionButton.extended(
              heroTag: 'fab_patients',
              onPressed: () => _ouvrirFormulaire(),
              icon: const Icon(Icons.person_add),
              label: const Text('Patient'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchField(
              hint: 'Nom, CIN, téléphone...',
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
                : _patients.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        message: 'Aucun patient trouvé',
                      )
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: _patients.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int i) {
                            final PatientDetail d = _patients[i];
                            return _PatientCard(
                              detail: d,
                              onTap: gerer
                                  ? () => _ouvrirFormulaire(d.patient)
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

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.detail, this.onTap});

  final PatientDetail detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Patient p = detail.patient;
    final String? medecin = detail.medecinNom;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarInitiales(
                prenom: p.prenom,
                nom: p.nom,
                couleur: AppColors.secondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nomComplet,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CIN ${p.cin} · ${p.age} ans · ${Patient.sexes[p.sexe] ?? p.sexe}'
                      '${p.groupeSanguin == null ? '' : ' · ${p.groupeSanguin}'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        InfoChip(
                          icon: Icons.apartment,
                          texte: detail.serviceNom ?? 'Sans service',
                        ),
                        if (medecin != null)
                          InfoChip(
                            icon: Icons.medical_services_outlined,
                            texte: medecin,
                          )
                        else
                          const StatusBadge(
                            libelle: 'Non affecté',
                            icon: Icons.warning_amber_rounded,
                            couleur: AppColors.warning,
                          ),
                      ],
                    ),
                  ],
                ),
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

  final PatientFiltre initial;
  final List<Service> services;

  @override
  State<_FiltreSheet> createState() => _FiltreSheetState();
}

class _FiltreSheetState extends State<_FiltreSheet> {
  int? _serviceId;
  String? _groupe;
  String? _sexe;
  bool _nonAffectes = false;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.initial.serviceId;
    _groupe = widget.initial.groupeSanguin;
    _sexe = widget.initial.sexe;
    _nonAffectes = widget.initial.nonAffectes;
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filtrer les patients',
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
            const SizedBox(height: 14),
            AppDropdownField<String?>(
              label: 'Groupe sanguin',
              icon: Icons.bloodtype_outlined,
              value: _groupe,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Tous')),
                for (final String g in Patient.groupesSanguins)
                  DropdownMenuItem<String?>(value: g, child: Text(g)),
              ],
              onChanged: (String? v) => setState(() => _groupe = v),
            ),
            const SizedBox(height: 16),
            const Text('Sexe'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tous'),
                  selected: _sexe == null,
                  onSelected: (_) => setState(() => _sexe = null),
                ),
                ChoiceChip(
                  label: const Text('Hommes'),
                  selected: _sexe == 'M',
                  onSelected: (_) => setState(() => _sexe = 'M'),
                ),
                ChoiceChip(
                  label: const Text('Femmes'),
                  selected: _sexe == 'F',
                  onSelected: (_) => setState(() => _sexe = 'F'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Seulement les patients non affectés'),
              value: _nonAffectes,
              onChanged: (bool v) => setState(() => _nonAffectes = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      PatientFiltre(texte: widget.initial.texte),
                    ),
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      PatientFiltre(
                        texte: widget.initial.texte,
                        serviceId: _serviceId,
                        groupeSanguin: _groupe,
                        sexe: _sexe,
                        nonAffectes: _nonAffectes,
                      ),
                    ),
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
