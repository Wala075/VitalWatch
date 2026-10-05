import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_dropdown_field.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../../../models/patient.dart';
import '../../../../../models/service.dart';
import '../../../../../models/utilisateur.dart';
import '../../../data/patient_repository.dart';
import '../../../data/service_repository.dart';
import '../../../domain/sante_simulee.dart';
import '../../../domain/staff_models.dart';
import '../../widgets/avatar_initiales.dart';
import '../../widgets/badges_sante.dart';
import '../../widgets/bouton_ajout.dart';
import '../../widgets/info_chip.dart';
import '../patient_form_screen.dart';
import '../patient_sante_screen.dart';

/// Liste des patients triée par niveau d'alerte (critiques en premier).
/// Toucher un patient ouvre son suivi de santé.
class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key, required this.role});

  final Role role;

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _Ligne {
  const _Ligne(this.detail, this.constantes, this.evaluation);

  final PatientDetail detail;
  final Constantes constantes;
  final Evaluation evaluation;
}

class _PatientsTabState extends State<PatientsTab> {
  final PatientRepository _repo = PatientRepository();
  final ServiceRepository _serviceRepo = ServiceRepository();

  List<PatientDetail> _patients = [];
  PatientFiltre _filtre = const PatientFiltre();

  /// Filtre rapide sur le niveau d'alerte (null = tous).
  NiveauAlerte? _niveau;
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
    if (!mounted || requete != _requete) return;
    setState(() {
      _patients = res;
      _chargement = false;
    });
  }

  Future<void> _ouvrirFiltres() async {
    final List<Service> services = await _serviceRepo.lister();
    if (!mounted) return;
    final PatientFiltre? res = await showModalBottomSheet<PatientFiltre>(
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
      MaterialPageRoute(
        builder: (_) => PatientFormScreen(
          peutSupprimer: widget.role.supprimerPatients,
        ),
      ),
    );
    if (modifie == true) _charger();
  }

  Future<void> _ouvrir(Patient p) async {
    final int? id = p.id;
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientSanteScreen(patientId: id, role: widget.role),
      ),
    );
    if (mounted) _charger();
  }

  @override
  Widget build(BuildContext context) {
    final List<_Ligne> lignes = [
      for (final PatientDetail d in _patients)
        _Ligne(
          d,
          SanteSimulee.instant(d.patient),
          SanteSimulee.evaluerPatient(d.patient),
        ),
    ]..sort((a, b) {
        final int n = b.evaluation.niveau.index.compareTo(a.evaluation.niveau.index);
        return n != 0
            ? n
            : a.detail.patient.nomComplet.compareTo(b.detail.patient.nomComplet);
      });

    int compter(NiveauAlerte n) =>
        lignes.where((l) => l.evaluation.niveau == n).length;
    final List<_Ligne> visibles = _niveau == null
        ? lignes
        : lignes.where((l) => l.evaluation.niveau == _niveau).toList();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          PageTitle(
            surtitre: 'Suivi des patients',
            titre: 'Patients',
            trailing: widget.role.gererPatients
                ? BoutonAjout(tooltip: 'Ajouter un patient', onPressed: _ajouter)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  selectionne: _niveau == null,
                  onTap: () => setState(() => _niveau = null),
                ),
                const SizedBox(width: 8),
                FiltreRapide(
                  libelle: 'Critique',
                  nombre: compter(NiveauAlerte.critique),
                  selectionne: _niveau == NiveauAlerte.critique,
                  couleur: AppColors.danger,
                  onTap: () => setState(() => _niveau = NiveauAlerte.critique),
                ),
                const SizedBox(width: 8),
                FiltreRapide(
                  libelle: 'À surveiller',
                  nombre: compter(NiveauAlerte.surveiller),
                  selectionne: _niveau == NiveauAlerte.surveiller,
                  couleur: AppColors.warning,
                  onTap: () => setState(() => _niveau = NiveauAlerte.surveiller),
                ),
                const SizedBox(width: 8),
                FiltreRapide(
                  libelle: 'Stable',
                  nombre: compter(NiveauAlerte.stable),
                  selectionne: _niveau == NiveauAlerte.stable,
                  couleur: AppColors.success,
                  onTap: () => setState(() => _niveau = NiveauAlerte.stable),
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
                        icon: Icons.people_outline,
                        message: 'Aucun patient trouvé',
                      )
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                          itemCount: visibles.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int i) {
                            final _Ligne l = visibles[i];
                            return _PatientCard(
                              ligne: l,
                              onTap: () => _ouvrir(l.detail.patient),
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
  const _PatientCard({required this.ligne, required this.onTap});

  final _Ligne ligne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Patient p = ligne.detail.patient;
    final String? medecin = ligne.detail.medecinNom;
    final Constantes c = ligne.constantes;
    final NiveauAlerte niveau = ligne.evaluation.niveau;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AvatarInitiales(
                    prenom: p.prenom,
                    nom: p.nom,
                    couleur: couleurNiveau(niveau),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nomComplet,
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
                          '${p.age} ans · ${Patient.sexes[p.sexe] ?? p.sexe}'
                          '${p.groupeSanguin == null ? '' : ' · ${p.groupeSanguin}'}'
                          ' · ${ligne.detail.serviceNom ?? 'Sans service'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  NiveauBadge(niveau: niveau),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Mesure(
                    icon: Icons.favorite_rounded,
                    texte: '${c.frequence} bpm',
                    niveau: SanteSimulee.niveauFrequence(c.frequence, p.age),
                  ),
                  _Mesure(
                    icon: Icons.air_rounded,
                    texte: '${c.spo2} %',
                    niveau: SanteSimulee.niveauSpo2(c.spo2),
                  ),
                  _Mesure(
                    icon: Icons.thermostat_rounded,
                    texte: '${c.temperatureTexte} °C',
                    niveau: SanteSimulee.niveauTemperature(c.temperature),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (medecin != null)
                InfoChip(icon: Icons.medical_services_outlined, texte: medecin)
              else
                const StatusBadge(
                  libelle: 'Aucun médecin affecté',
                  icon: Icons.warning_amber_rounded,
                  couleur: AppColors.warning,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mesure extends StatelessWidget {
  const _Mesure({required this.icon, required this.texte, required this.niveau});

  final IconData icon;
  final String texte;
  final NiveauAlerte niveau;

  @override
  Widget build(BuildContext context) {
    final bool normal = niveau == NiveauAlerte.stable;
    final Color couleur = normal ? AppColors.textSecondary : couleurNiveau(niveau);

    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: normal ? AppColors.primary : couleur),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: normal ? FontWeight.w500 : FontWeight.w800,
                color: normal ? AppColors.textPrimary : couleur,
              ),
            ),
          ),
        ],
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
