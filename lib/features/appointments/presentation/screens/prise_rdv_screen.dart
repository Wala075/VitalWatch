import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/medecin.dart';
import '../../../../models/patient.dart';
import '../../../../models/utilisateur.dart';
import '../../domain/rdv_manager.dart';
import '../../domain/rdv_models.dart';
import '../../domain/rdv_regles.dart';
import '../widgets/rdv_widgets.dart';

/// Prise de rendez-vous : patient (pour lui-même) ou personnel (pour un patient).
/// Renvoie true si un RDV a été créé.
class PriseRdvScreen extends StatefulWidget {
  const PriseRdvScreen({super.key, required this.utilisateur});

  final Utilisateur utilisateur;

  @override
  State<PriseRdvScreen> createState() => _PriseRdvScreenState();
}

class _PriseRdvScreenState extends State<PriseRdvScreen> {
  final RdvManager _manager = RdvManager();
  final TextEditingController _motif = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  static const int _nbJours = 14;

  List<Medecin> _medecins = [];
  List<Patient> _patients = [];
  int? _patientId;
  int? _medecinId;
  TypeRdv _type = TypeRdv.presentiel;
  DateTime _jour = DateTime.now();
  List<DateTime> _horaires = [];
  DateTime? _horaire;
  bool _chargement = true;
  bool _chargementHoraires = false;
  bool _envoi = false;

  bool get _estPatient => widget.utilisateur.role == Role.patient;

  /// Médecin connecté : il réserve dans SON agenda, pour SES patients.
  bool get _estMedecin => widget.utilisateur.role == Role.medecin;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  Future<void> _initialiser() async {
    final List<Medecin> medecins =
        await _manager.medecins(disponiblesSeulement: true);
    List<Patient> patients = [];
    int? patientId;
    int? medecinId;

    if (_estPatient) {
      patientId = widget.utilisateur.refId;
      final int? pid = patientId;
      final Patient? p = pid == null ? null : await _manager.patient(pid);
      medecinId = p?.medecinId; // son médecin traitant par défaut
    } else {
      patients = await _manager.patients(widget.utilisateur);
      if (widget.utilisateur.role == Role.medecin) {
        medecinId = widget.utilisateur.refId;
      }
    }
    if (_estMedecin) {
      medecinId = widget.utilisateur.refId;
    } else if (!medecins.any((Medecin m) => m.id == medecinId)) {
      medecinId = medecins.isEmpty ? null : medecins.first.id;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _medecins = medecins;
      _patients = patients;
      _patientId = patientId;
      _medecinId = medecinId;
      _chargement = false;
    });
    _chargerHoraires();
  }

  Future<void> _chargerHoraires() async {
    final int? mid = _medecinId;
    if (mid == null) {
      return;
    }
    setState(() {
      _chargementHoraires = true;
      _horaire = null;
    });
    final List<DateTime> h = await _manager.horairesLibres(mid, _jour);
    if (!mounted) {
      return;
    }
    setState(() {
      _horaires = h;
      _chargementHoraires = false;
    });
  }

  Future<void> _valider([DateTime? force]) async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final int? pid = _patientId;
    final int? mid = _medecinId;
    final DateTime? quand = force ?? _horaire;
    if (pid == null || mid == null) {
      afficherErreur(context, const RdvException('Choisissez le patient et le médecin'));
      return;
    }
    if (quand == null) {
      afficherErreur(context, const RdvException('Choisissez un horaire'));
      return;
    }
    setState(() => _envoi = true);
    try {
      final RendezVous r = await _manager.reserver(
        patientId: pid,
        medecinId: mid,
        dateHeure: quand,
        type: _type,
        motif: _motif.text,
        auteur: widget.utilisateur,
      );
      if (!mounted) {
        return;
      }
      afficherInfo(
        context,
        r.statut == StatutRdv.enAttente
            ? 'Demande envoyée : en attente de confirmation'
            : 'Rendez-vous confirmé le ${RdvFormat.complet(r.dateHeure)}',
      );
      Navigator.pop(context, true);
    } on ConflitCreneauException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _envoi = false);
      await _proposer(e);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _envoi = false);
      afficherErreur(context, e);
    }
  }

  /// Conflit : on propose le prochain créneau libre.
  Future<void> _proposer(ConflitCreneauException e) async {
    final DateTime? prop = e.proposition;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: const Icon(Icons.event_busy_rounded, color: AppColors.warning),
        title: Text(e.message),
        content: Text(
          prop == null
              ? 'Aucun créneau libre dans les 30 prochains jours pour ce médecin.'
              : 'Prochain créneau libre :\n${RdvFormat.complet(prop)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Choisir autre chose'),
          ),
          if (prop != null)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Réserver ce créneau'),
            ),
        ],
      ),
    );
    if (ok == true && prop != null) {
      await _valider(prop);
    } else {
      _chargerHoraires();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prendre rendez-vous')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (!_estPatient) ...[
                    AppDropdownField<int>(
                      label: 'Patient',
                      icon: Icons.person_outline,
                      value: _patientId,
                      items: [
                        for (final Patient p in _patients)
                          DropdownMenuItem<int>(
                            value: p.id,
                            child: Text('${p.nomComplet} · CIN ${p.cin}'),
                          ),
                      ],
                      validator: (int? v) => v == null ? 'Choisissez un patient' : null,
                      onChanged: (int? v) {
                        setState(() => _patientId = v);
                        if (_estMedecin) {
                          return; // le médecin reste lui-même
                        }
                        // Médecin traitant proposé par défaut.
                        for (final Patient p in _patients) {
                          if (p.id == v &&
                              _medecins.any((Medecin m) => m.id == p.medecinId)) {
                            setState(() => _medecinId = p.medecinId);
                            _chargerHoraires();
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_estMedecin && _patients.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Text(
                        "Aucun patient ne vous est affecté pour l'instant "
                        '(affectation dans Services & Personnel).',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  if (_estMedecin)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.medical_services_outlined, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Dans votre agenda : Dr ${widget.utilisateur.nomComplet}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                  AppDropdownField<int>(
                    label: 'Médecin',
                    icon: Icons.medical_services_outlined,
                    value: _medecinId,
                    items: [
                      for (final Medecin m in _medecins)
                        DropdownMenuItem<int>(
                          value: m.id,
                          child: Text('${m.nomComplet} · ${m.specialite}'),
                        ),
                    ],
                    validator: (int? v) => v == null ? 'Choisissez un médecin' : null,
                    onChanged: (int? v) {
                      setState(() => _medecinId = v);
                      _chargerHoraires();
                    },
                  ),
                  const SizedBox(height: 16),
                  const _Titre('Type de consultation'),
                  SegmentedButton<TypeRdv>(
                    segments: const [
                      ButtonSegment<TypeRdv>(
                        value: TypeRdv.presentiel,
                        icon: Icon(Icons.local_hospital_rounded),
                        label: Text('Présentiel'),
                      ),
                      ButtonSegment<TypeRdv>(
                        value: TypeRdv.visio,
                        icon: Icon(Icons.videocam_rounded),
                        label: Text('Visio'),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (Set<TypeRdv> s) => setState(() => _type = s.first),
                  ),
                  const SizedBox(height: 16),
                  const _Titre('Jour'),
                  SizedBox(
                    height: 74,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _nbJours,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int i) {
                        final DateTime n = DateTime.now();
                        final DateTime j = DateTime(n.year, n.month, n.day + i);
                        final bool actif = RdvFormat.memeJour(j, _jour);
                        return _CarteJour(
                          jour: j,
                          actif: actif,
                          onTap: () {
                            setState(() => _jour = j);
                            _chargerHoraires();
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _Titre('Horaires libres'),
                  if (_chargementHoraires)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_horaires.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_busy_rounded, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Aucun horaire libre ce jour-là')),
                          TextButton(
                            onPressed: _medecinId == null ? null : _chercherProchain,
                            child: const Text('Prochain libre'),
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final DateTime h in _horaires)
                          ChoiceChip(
                            label: Text(RdvFormat.heure(h)),
                            selected: _horaire == h,
                            onSelected: (_) => setState(() => _horaire = h),
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _motif,
                    label: 'Motif',
                    icon: Icons.edit_note_rounded,
                    hint: 'Ex : contrôle de tension, douleurs...',
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (String? v) => (v == null || v.trim().length < 3)
                        ? 'Indiquez le motif (3 caractères minimum)'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: _estPatient ? 'Demander le rendez-vous' : 'Réserver',
                    icon: Icons.event_available_rounded,
                    loading: _envoi,
                    onPressed: () => _valider(),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _chercherProchain() async {
    final int? mid = _medecinId;
    if (mid == null) {
      return;
    }
    final DateTime? p = await _manager.prochainHoraireLibre(mid, _jour);
    if (!mounted) {
      return;
    }
    if (p == null) {
      afficherInfo(context, 'Aucun créneau libre dans les 30 prochains jours');
      return;
    }
    setState(() => _jour = DateTime(p.year, p.month, p.day));
    await _chargerHoraires();
    if (mounted) {
      setState(() => _horaire = p);
    }
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texte,
        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      ),
    );
  }
}

class _CarteJour extends StatelessWidget {
  const _CarteJour({required this.jour, required this.actif, required this.onTap});

  final DateTime jour;
  final bool actif;
  final VoidCallback onTap;

  static const List<String> _jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 58,
        decoration: BoxDecoration(
          color: actif ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _jours[jour.weekday - 1],
              style: TextStyle(
                fontSize: 12,
                color: actif ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            Text(
              '${jour.day}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: actif ? Colors.white : AppColors.textPrimary,
              ),
            ),
            Text(
              RdvFormat.mois(jour),
              style: TextStyle(
                fontSize: 10,
                color: actif ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
