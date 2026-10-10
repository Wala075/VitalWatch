import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/ecg_painter.dart';
import '../../../../core/widgets/page_title.dart';
import '../../../../models/medecin.dart';
import '../../../../models/patient.dart';
import '../../../../models/service.dart';
import '../../../../models/utilisateur.dart';
import '../../data/medecin_repository.dart';
import '../../data/patient_repository.dart';
import '../../data/service_repository.dart';
import '../../domain/disponibilite.dart';
import '../../domain/sante_simulee.dart';
import '../widgets/avatar_initiales.dart';
import '../widgets/badges_sante.dart';
import '../widgets/barre_retour.dart';
import 'medecin_detail_screen.dart';
import 'patient_form_screen.dart';

/// Suivi de santé d'un patient : constantes vitales (simulées en attendant
/// le module 2), alertes, tendance de la semaine et équipe de prise en charge.
class PatientSanteScreen extends StatefulWidget {
  const PatientSanteScreen({
    super.key,
    required this.patientId,
    required this.role,
  });

  final int patientId;
  final Role role;

  @override
  State<PatientSanteScreen> createState() => _PatientSanteScreenState();
}

class _PatientSanteScreenState extends State<PatientSanteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ecg;
  Timer? _timer;
  int _tick = 0;

  Patient? _patient;
  String? _serviceNom;
  Medecin? _medecin;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _ecg = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    // Nouvelle mesure simulée toutes les 3 secondes.
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _tick++);
    });
    _charger();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ecg.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final Patient? p = await PatientRepository().parId(widget.patientId);
    if (!mounted) return;
    if (p == null) {
      // Patient supprimé depuis le formulaire.
      Navigator.pop(context);
      return;
    }
    final int? serviceId = p.serviceId;
    final int? medecinId = p.medecinId;
    final Service? service =
        serviceId == null ? null : await ServiceRepository().parId(serviceId);
    final Medecin? medecin =
        medecinId == null ? null : await MedecinRepository().parId(medecinId);
    if (!mounted) return;

    // Le tracé ECG défile au rythme du cœur (un battement par cycle).
    final int bpm = SanteSimulee.instant(p).frequence.clamp(40, 180);
    _ecg.duration = Duration(milliseconds: (60000 / bpm).round());
    _ecg.repeat();

    setState(() {
      _patient = p;
      _serviceNom = service?.nom;
      _medecin = medecin;
      _chargement = false;
    });
  }

  Future<void> _modifier() async {
    final Patient? p = _patient;
    if (p == null) return;
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PatientFormScreen(
          patient: p,
          peutSupprimer: widget.role.supprimerPatients,
        ),
      ),
    );
    if (modifie == true) _charger();
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

  @override
  Widget build(BuildContext context) {
    final Patient? p = _patient;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              BarreRetour(
                titre: 'Suivi de santé',
                actions: [
                  if (widget.role.gererPatients && p != null)
                    IconButton(
                      tooltip: 'Modifier la fiche',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _modifier,
                    ),
                ],
              ),
              Expanded(
                child: _chargement || p == null
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: _contenu(p),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenu(Patient p) {
    final Constantes c = SanteSimulee.instant(p, tick: _tick);
    final Evaluation e = SanteSimulee.evaluer(c, p.age);
    final String? groupe = p.groupeSanguin;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        // ------------------------------------------------------ identité
        CarteBlanche(
          child: Row(
            children: [
              AvatarInitiales(
                prenom: p.prenom,
                nom: p.nom,
                couleur: couleurNiveau(e.niveau),
                rayon: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nomComplet,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.age} ans · ${Patient.sexes[p.sexe] ?? p.sexe}'
                      '${groupe == null ? '' : ' · $groupe'}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      'CIN ${p.cin}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    NiveauBadge(niveau: e.niveau),
                  ],
                ),
              ),
            ],
          ),
        ),

        // -------------------------------------------------------- alertes
        if (e.motifs.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CarteAlerte(evaluation: e),
        ],

        // --------------------------------------------------------- cœur
        const SizedBox(height: 12),
        _carteCoeur(c, SanteSimulee.niveauFrequence(c.frequence, p.age)),
        const SizedBox(height: 12),

        // ----------------------------------------------------- constantes
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _Tuile(
              icon: Icons.air_rounded,
              libelle: 'Saturation SpO₂',
              valeur: '${c.spo2}',
              unite: '%',
              niveau: SanteSimulee.niveauSpo2(c.spo2),
            ),
            _Tuile(
              icon: Icons.speed_rounded,
              libelle: 'Tension',
              valeur: c.tension,
              unite: 'mmHg',
              niveau: SanteSimulee.niveauTension(c.systolique, c.diastolique),
            ),
            _Tuile(
              icon: Icons.thermostat_rounded,
              libelle: 'Température',
              valeur: c.temperatureTexte,
              unite: '°C',
              niveau: SanteSimulee.niveauTemperature(c.temperature),
            ),
            _Tuile(
              icon: Icons.water_drop_rounded,
              libelle: 'Glycémie',
              valeur: c.glycemieTexte,
              unite: 'g/L',
              niveau: SanteSimulee.niveauGlycemie(c.glycemie),
            ),
          ],
        ),

        // ------------------------------------------------------- semaine
        const SizedBox(height: 24),
        const SectionHeader(titre: 'Fréquence cardiaque · 7 jours'),
        const SizedBox(height: 12),
        CarteBlanche(
          child: _GraphiqueSemaine(
            valeurs: SanteSimulee.frequenceSemaine(p),
            age: p.age,
          ),
        ),

        // ------------------------------------------------ prise en charge
        const SizedBox(height: 24),
        const SectionHeader(titre: 'Prise en charge'),
        const SizedBox(height: 12),
        _priseEnCharge(p),

        const SizedBox(height: 18),
        const Text(
          'Constantes simulées — elles seront remplacées par les mesures '
          'réelles du module Suivi vital.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _carteCoeur(Constantes c, NiveauAlerte niveau) {
    return Container(
      height: 190,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Fréquence cardiaque',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _ecg,
                builder: (BuildContext context, Widget? child) => Opacity(
                  opacity: 0.4 + 0.6 * (0.5 + 0.5 * math.sin(_ecg.value * 2 * math.pi)),
                  child: child,
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.ecg,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'SIMULATION',
                style: TextStyle(
                  color: AppColors.ecg,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  '${c.frequence}',
                  key: ValueKey<int>(c.frequence),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'bpm',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ),
              const Spacer(),
              if (niveau != NiveauAlerte.stable)
                NiveauBadge(niveau: niveau)
              else
                const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.danger,
                  size: 30,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AnimatedBuilder(
              animation: _ecg,
              builder: (BuildContext context, Widget? child) => CustomPaint(
                size: Size.infinite,
                painter: EcgPainter(
                  couleur: niveau == NiveauAlerte.stable
                      ? AppColors.ecg
                      : couleurNiveau(niveau),
                  phase: _ecg.value,
                  epaisseur: 2.2,
                  lueur: true,
                  battements: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priseEnCharge(Patient p) {
    final Medecin? m = _medecin;
    final String? urgenceNom = p.contactUrgenceNom;
    final String? urgenceTel = p.contactUrgenceTel;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.apartment_rounded, color: AppColors.primary),
            title: const Text('Service'),
            subtitle: Text(_serviceNom ?? 'Non affecté'),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(
              Icons.medical_services_rounded,
              color: AppColors.primary,
            ),
            title: const Text('Médecin traitant'),
            subtitle: Text(
              m == null ? 'Aucun médecin affecté' : '${m.nomComplet} · ${m.specialite}',
            ),
            trailing: m == null ? null : const Icon(Icons.chevron_right_rounded),
            onTap: m == null ? null : () => _ouvrirMedecin(m),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.phone_rounded, color: AppColors.primary),
            title: const Text('Téléphone'),
            subtitle: Text(Formatters.telephone(p.telephone)),
          ),
          if (urgenceNom != null && urgenceNom.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.contact_phone_rounded, color: AppColors.danger),
              title: const Text("Contact d'urgence"),
              subtitle: Text(
                urgenceTel == null || urgenceTel.isEmpty
                    ? urgenceNom
                    : '$urgenceNom · ${Formatters.telephone(urgenceTel)}',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CarteAlerte extends StatelessWidget {
  const _CarteAlerte({required this.evaluation});

  final Evaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final Color couleur = couleurNiveau(evaluation.niveau);
    final bool critique = evaluation.niveau == NiveauAlerte.critique;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                critique ? Icons.error_rounded : Icons.warning_amber_rounded,
                color: couleur,
              ),
              const SizedBox(width: 8),
              Text(
                critique ? 'Intervention recommandée' : 'À surveiller',
                style: TextStyle(fontWeight: FontWeight.w800, color: couleur),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final String motif in evaluation.motifs)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• $motif',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tuile extends StatelessWidget {
  const _Tuile({
    required this.icon,
    required this.libelle,
    required this.valeur,
    required this.unite,
    required this.niveau,
  });

  final IconData icon;
  final String libelle;
  final String valeur;
  final String unite;
  final NiveauAlerte niveau;

  @override
  Widget build(BuildContext context) {
    final Color couleur = couleurNiveau(niveau);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: niveau == NiveauAlerte.stable
            ? null
            : Border.all(color: couleur.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const Spacer(),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  valeur,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unite,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            libelle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Histogramme simple : fréquence cardiaque moyenne des 7 derniers jours.
class _GraphiqueSemaine extends StatelessWidget {
  const _GraphiqueSemaine({required this.valeurs, required this.age});

  final List<int> valeurs;
  final int age;

  @override
  Widget build(BuildContext context) {
    final int max = valeurs.fold<int>(0, math.max);
    final int min = valeurs.fold<int>(1000, math.min);
    final DateTime aujourdHui = DateTime.now();
    const double hauteur = 90;

    return Column(
      children: [
        SizedBox(
          height: hauteur + 34,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < valeurs.length; i++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${valeurs[i]}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 18,
                        // Les écarts sont accentués : la barre la plus basse
                        // fait 30 % de la hauteur, la plus haute 100 %.
                        height: hauteur *
                            (max == min
                                ? 0.7
                                : 0.3 + 0.7 * (valeurs[i] - min) / (max - min)),
                        decoration: BoxDecoration(
                          color: couleurNiveau(
                            SanteSimulee.niveauFrequence(valeurs[i], age),
                          ).withValues(alpha: i == valeurs.length - 1 ? 1 : 0.55),
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (int i = 0; i < valeurs.length; i++)
              Expanded(
                child: Text(
                  i == valeurs.length - 1
                      ? 'Auj.'
                      : Horaire.joursCourts[aujourdHui
                              .subtract(Duration(days: valeurs.length - 1 - i))
                              .weekday -
                          1],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        i == valeurs.length - 1 ? FontWeight.w800 : FontWeight.w500,
                    color: i == valeurs.length - 1
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
