import 'package:flutter/material.dart';

import '../../../../../core/routing/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../models/medecin.dart';
import '../../../../../models/patient.dart';
import '../../../../../models/utilisateur.dart';
import '../../../../../shared_providers/session.dart';
import '../../../data/horaire_repository.dart';
import '../../../data/medecin_repository.dart';
import '../../../data/patient_repository.dart';
import '../../../data/service_repository.dart';
import '../../../domain/disponibilite.dart';
import '../../../domain/sante_simulee.dart';
import '../../../domain/staff_models.dart';
import '../../widgets/avatar_initiales.dart';
import '../../widgets/badges_sante.dart';
import '../../widgets/profil_sheet.dart';
import '../medecin_detail_screen.dart';
import '../patient_sante_screen.dart';

/// Tableau de bord : qui est en service, quels patients surveiller,
/// et accès à tous les modules.
class AccueilTab extends StatefulWidget {
  const AccueilTab({super.key, required this.role, required this.onAller});

  final Role role;
  final ValueChanged<int> onAller;

  @override
  State<AccueilTab> createState() => _AccueilTabState();
}

class _MedecinEnService {
  const _MedecinEnService(this.detail, this.disponibilite);

  final MedecinDetail detail;
  final Disponibilite disponibilite;
}

class _PatientEnAlerte {
  const _PatientEnAlerte(this.detail, this.evaluation);

  final PatientDetail detail;
  final Evaluation evaluation;
}

class _AccueilTabState extends State<AccueilTab> {
  bool _chargement = true;
  List<MedecinDetail> _medecins = [];
  Map<int, List<Creneau>> _horaires = {};
  List<PatientDetail> _patients = [];
  List<ServiceStats> _services = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final List<MedecinDetail> medecins =
        await MedecinRepository().rechercher(const MedecinFiltre());
    final Map<int, List<Creneau>> horaires = await HoraireRepository().tous();
    final List<PatientDetail> patients =
        await PatientRepository().rechercher(const PatientFiltre());
    final List<ServiceStats> services = await ServiceRepository().statistiques();
    if (!mounted) return;
    setState(() {
      _medecins = medecins;
      _horaires = horaires;
      _patients = patients;
      _services = services;
      _chargement = false;
    });
  }

  Future<void> _ouvrirMedecin(Medecin m) async {
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

  Future<void> _ouvrirPatient(Patient p) async {
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

  String get _salutation {
    final int h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }

    final DateTime maintenant = DateTime.now();
    final List<_MedecinEnService> enService = [];
    for (final MedecinDetail d in _medecins) {
      final Disponibilite dispo = Disponibilite.calculer(
        d.medecin,
        _horaires[d.medecin.id] ?? const [],
        maintenant,
      );
      if (dispo.etat == EtatMedecin.enService) {
        enService.add(_MedecinEnService(d, dispo));
      }
    }

    final List<_PatientEnAlerte> alertes = [];
    for (final PatientDetail p in _patients) {
      final Evaluation e = SanteSimulee.evaluerPatient(p.patient);
      if (e.niveau != NiveauAlerte.stable) {
        alertes.add(_PatientEnAlerte(p, e));
      }
    }
    alertes.sort(
      (a, b) => b.evaluation.niveau.index.compareTo(a.evaluation.niveau.index),
    );

    int places = 0;
    int occupes = 0;
    for (final ServiceStats s in _services) {
      places += s.service.capacite;
      occupes += s.nbPatients;
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            _entete(),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _Kpi(
                  icon: Icons.medical_services_rounded,
                  couleur: AppColors.success,
                  valeur: '${enService.length} / ${_medecins.length}',
                  libelle: 'Médecins en service',
                  onTap: () => widget.onAller(1),
                ),
                _Kpi(
                  icon: Icons.people_alt_rounded,
                  couleur: AppColors.primary,
                  valeur: '${_patients.length}',
                  libelle: 'Patients suivis',
                  onTap: () => widget.onAller(2),
                ),
                _Kpi(
                  icon: Icons.warning_amber_rounded,
                  couleur: alertes.isEmpty ? AppColors.success : AppColors.danger,
                  valeur: '${alertes.length}',
                  libelle: 'Patients à surveiller',
                  onTap: () => widget.onAller(2),
                ),
                _Kpi(
                  icon: Icons.bed_rounded,
                  couleur: AppColors.purple,
                  valeur: places == 0 ? '0 %' : '${(occupes * 100 / places).round()} %',
                  libelle: 'Lits occupés',
                  onTap: () => widget.onAller(3),
                ),
              ],
            ),
            const SizedBox(height: 26),
            SectionHeader(
              titre: 'En service maintenant',
              action: 'Tous',
              onAction: () => widget.onAller(1),
            ),
            const SizedBox(height: 12),
            if (enService.isEmpty)
              const _Vide(
                icon: Icons.nights_stay_rounded,
                texte: 'Aucun médecin en consultation en ce moment',
              )
            else
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: enService.length,
                  separatorBuilder: (BuildContext context, int i) =>
                      const SizedBox(width: 12),
                  itemBuilder: (BuildContext context, int i) {
                    final _MedecinEnService m = enService[i];
                    return _CarteMedecin(
                      medecin: m.detail.medecin,
                      disponibilite: m.disponibilite,
                      onTap: () => _ouvrirMedecin(m.detail.medecin),
                    );
                  },
                ),
              ),
            const SizedBox(height: 26),
            SectionHeader(
              titre: 'Patients à surveiller',
              action: 'Tous',
              onAction: () => widget.onAller(2),
            ),
            const SizedBox(height: 12),
            if (alertes.isEmpty)
              const _Vide(
                icon: Icons.verified_rounded,
                texte: 'Tous les patients sont stables',
              )
            else
              for (final _PatientEnAlerte a in alertes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LigneAlerte(
                    alerte: a,
                    onTap: () => _ouvrirPatient(a.detail.patient),
                  ),
                ),
            const SizedBox(height: 16),
            const SectionHeader(titre: 'Autres modules'),
            const SizedBox(height: 12),
            const Row(
              children: [
                _Module(
                  icon: Icons.monitor_heart_rounded,
                  libelle: 'Suivi vital',
                  route: AppRoutes.patientMonitoring,
                ),
                SizedBox(width: 10),
                _Module(
                  icon: Icons.local_hospital_rounded,
                  libelle: 'Ambulances',
                  route: AppRoutes.ambulanceDispatch,
                ),
                SizedBox(width: 10),
                _Module(
                  icon: Icons.event_rounded,
                  libelle: 'Rendez-vous',
                  route: AppRoutes.appointments,
                ),
                SizedBox(width: 10),
                _Module(
                  icon: Icons.medication_rounded,
                  libelle: 'Ordonnances',
                  route: AppRoutes.prescriptions,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Constantes vitales simulées en attendant le module Suivi vital.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entete() {
    final Utilisateur? u = Session.utilisateur;
    final String nom = u == null || u.nomComplet.isEmpty ? 'Personnel' : u.nomComplet;

    return Row(
      children: [
        GestureDetector(
          onTap: () => showProfilSheet(context),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
            ),
            child: Text(
              nom.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _salutation,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                nom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.role.libelle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.icon,
    required this.couleur,
    required this.valeur,
    required this.libelle,
    required this.onTap,
  });

  final IconData icon;
  final Color couleur;
  final String valeur;
  final String libelle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: couleur),
              ),
              const Spacer(),
              Text(
                valeur,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarteMedecin extends StatelessWidget {
  const _CarteMedecin({
    required this.medecin,
    required this.disponibilite,
    required this.onTap,
  });

  final Medecin medecin;
  final Disponibilite disponibilite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DateTime? fin = disponibilite.jusqua;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          width: 156,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvatarInitiales(prenom: medecin.prenom, nom: medecin.nom),
                const SizedBox(height: 8),
                Text(
                  medecin.nomComplet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                Text(
                  medecin.specialite,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: couleurEtat(disponibilite.etat),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      fin == null ? 'En service' : "Jusqu'à ${Horaire.format(fin.hour * 60 + fin.minute)}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LigneAlerte extends StatelessWidget {
  const _LigneAlerte({required this.alerte, required this.onTap});

  final _PatientEnAlerte alerte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Patient p = alerte.detail.patient;
    final List<String> motifs = alerte.evaluation.motifs;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AvatarInitiales(
                prenom: p.prenom,
                nom: p.nom,
                couleur: couleurNiveau(alerte.evaluation.niveau),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nomComplet,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      motifs.isEmpty ? '' : motifs.first,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              NiveauBadge(niveau: alerte.evaluation.niveau),
            ],
          ),
        ),
      ),
    );
  }
}

class _Module extends StatelessWidget {
  const _Module({required this.icon, required this.libelle, required this.route});

  final IconData icon;
  final String libelle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(context, route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(height: 6),
                Text(
                  libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.icon, required this.texte});

  final IconData icon;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
