import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/page_title.dart';
import '../../../../models/medecin.dart';
import '../../../../models/patient.dart';
import '../../../../models/service.dart';
import '../../../../models/utilisateur.dart';
import '../../data/horaire_repository.dart';
import '../../data/medecin_repository.dart';
import '../../data/patient_repository.dart';
import '../../data/service_repository.dart';
import '../../domain/disponibilite.dart';
import '../../domain/sante_simulee.dart';
import '../../domain/staff_manager.dart';
import '../widgets/avatar_initiales.dart';
import '../widgets/badges_sante.dart';
import '../widgets/barre_retour.dart';
import '../widgets/info_chip.dart';
import 'horaires_screen.dart';
import 'medecin_form_screen.dart';
import 'patient_sante_screen.dart';

/// Fiche d'un médecin : disponibilité (maintenant + semaine), charge
/// et patients suivis. L'admin peut modifier la fiche, les horaires
/// et mettre le médecin en congé.
class MedecinDetailScreen extends StatefulWidget {
  const MedecinDetailScreen({
    super.key,
    required this.medecinId,
    required this.role,
  });

  final int medecinId;
  final Role role;

  @override
  State<MedecinDetailScreen> createState() => _MedecinDetailScreenState();
}

class _MedecinDetailScreenState extends State<MedecinDetailScreen> {
  Medecin? _medecin;
  String? _serviceNom;
  List<Creneau> _creneaux = [];
  List<Patient> _patients = [];
  bool _chargement = true;
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final Medecin? m = await MedecinRepository().parId(widget.medecinId);
    if (!mounted) return;
    if (m == null) {
      // Médecin supprimé depuis le formulaire.
      Navigator.pop(context);
      return;
    }
    final int? serviceId = m.serviceId;
    final Service? service =
        serviceId == null ? null : await ServiceRepository().parId(serviceId);
    final List<Creneau> creneaux =
        await HoraireRepository().parMedecin(widget.medecinId);
    final List<Patient> patients =
        await PatientRepository().parMedecin(widget.medecinId);
    if (!mounted) return;
    setState(() {
      _medecin = m;
      _serviceNom = service?.nom;
      _creneaux = creneaux;
      _patients = patients;
      _chargement = false;
    });
  }

  Future<void> _modifier() async {
    final Medecin? m = _medecin;
    if (m == null) return;
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MedecinFormScreen(medecin: m)),
    );
    if (modifie == true) _charger();
  }

  Future<void> _modifierHoraires() async {
    final Medecin? m = _medecin;
    if (m == null) return;
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HorairesScreen(medecin: m, creneaux: _creneaux),
      ),
    );
    if (modifie == true) {
      _charger();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horaires enregistrés')),
      );
    }
  }

  Future<void> _basculerConge(bool enConge) async {
    setState(() => _occupe = true);
    await StaffManager().changerDisponibilite(widget.medecinId, !enConge);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enConge ? 'Médecin mis en congé' : 'Retour de congé enregistré'),
      ),
    );
    await _charger();
    if (mounted) setState(() => _occupe = false);
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

  @override
  Widget build(BuildContext context) {
    final bool gerer = widget.role.gererMedecins;
    final Medecin? m = _medecin;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              BarreRetour(
                titre: 'Fiche médecin',
                actions: [
                  if (gerer && m != null)
                    IconButton(
                      tooltip: 'Modifier la fiche',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _modifier,
                    ),
                ],
              ),
              Expanded(
                child: _chargement || m == null
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: _contenu(m, gerer),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenu(Medecin m, bool gerer) {
    final DateTime maintenant = DateTime.now();
    final Disponibilite dispo = Disponibilite.calculer(m, _creneaux, maintenant);
    final List<(Patient, Evaluation)> suivis = [
      for (final Patient p in _patients) (p, SanteSimulee.evaluerPatient(p)),
    ]..sort((a, b) => b.$2.niveau.index.compareTo(a.$2.niveau.index));
    final int aSurveiller =
        suivis.where((s) => s.$2.niveau != NiveauAlerte.stable).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        // ------------------------------------------------------ identité
        CarteBlanche(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AvatarInitiales(prenom: m.prenom, nom: m.nom, rayon: 40),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: couleurEtat(dispo.etat),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                m.nomComplet,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${m.specialite} · ${_serviceNom ?? 'Sans service'}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              EtatMedecinBadge(disponibilite: dispo, maintenant: maintenant),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 6,
                children: [
                  InfoChip(icon: Icons.badge_outlined, texte: m.matricule),
                  InfoChip(
                    icon: Icons.phone_outlined,
                    texte: Formatters.telephone(m.telephone),
                  ),
                  InfoChip(icon: Icons.mail_outline, texte: m.email),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --------------------------------------------------------- charge
        Row(
          children: [
            _Chiffre(
              valeur: '${_patients.length}',
              libelle: 'patients',
              couleur: AppColors.primary,
            ),
            const SizedBox(width: 10),
            _Chiffre(
              valeur: '$aSurveiller',
              libelle: 'à surveiller',
              couleur: aSurveiller == 0 ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 10),
            _Chiffre(
              valeur: '${Horaire.heuresParSemaine(_creneaux)} h',
              libelle: '${Horaire.joursTravailles(_creneaux)} j / semaine',
              couleur: AppColors.purple,
            ),
          ],
        ),

        // ---------------------------------------------------------- congé
        if (gerer) ...[
          const SizedBox(height: 12),
          CarteBlanche(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: SwitchListTile(
              value: !m.disponible,
              onChanged: _occupe ? null : _basculerConge,
              secondary: const Icon(Icons.event_busy_rounded),
              title: const Text(
                'En congé',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Ne reçoit plus de nouveaux patients',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],

        // ------------------------------------------------------- semaine
        const SizedBox(height: 24),
        SectionHeader(
          titre: 'Horaires de la semaine',
          action: gerer ? 'Modifier' : null,
          onAction: gerer ? _modifierHoraires : null,
        ),
        const SizedBox(height: 12),
        CarteBlanche(
          child: _SemaineMedecin(creneaux: _creneaux, maintenant: maintenant),
        ),

        // ------------------------------------------------------ patients
        const SizedBox(height: 24),
        SectionHeader(titre: 'Patients suivis (${_patients.length})'),
        const SizedBox(height: 12),
        if (suivis.isEmpty)
          const CarteBlanche(
            child: Text(
              'Aucun patient affecté à ce médecin',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          for (final s in suivis)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  onTap: () => _ouvrirPatient(s.$1),
                  leading: AvatarInitiales(
                    prenom: s.$1.prenom,
                    nom: s.$1.nom,
                    couleur: couleurNiveau(s.$2.niveau),
                  ),
                  title: Text(
                    s.$1.nomComplet,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${s.$1.age} ans · CIN ${s.$1.cin}'),
                  trailing: NiveauBadge(niveau: s.$2.niveau),
                ),
              ),
            ),
      ],
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({
    required this.valeur,
    required this.libelle,
    required this.couleur,
  });

  final String valeur;
  final String libelle;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              valeur,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: couleur,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              libelle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Planning hebdomadaire : une ligne par jour avec une barre horaire,
/// le jour courant en surbrillance et un repère « maintenant ».
class _SemaineMedecin extends StatelessWidget {
  const _SemaineMedecin({required this.creneaux, required this.maintenant});

  final List<Creneau> creneaux;
  final DateTime maintenant;

  @override
  Widget build(BuildContext context) {
    if (creneaux.isEmpty) {
      return const Text(
        'Aucun horaire défini',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    // Échelle commune à toute la semaine (arrondie à l'heure).
    int debutAxe = 24 * 60;
    int finAxe = 0;
    for (final Creneau c in creneaux) {
      if (c.debut < debutAxe) debutAxe = c.debut;
      if (c.fin > finAxe) finAxe = c.fin;
    }
    debutAxe = (debutAxe ~/ 60) * 60;
    finAxe = ((finAxe + 59) ~/ 60) * 60;
    final int minuteNow = maintenant.hour * 60 + maintenant.minute;

    return Column(
      children: [
        for (int jour = 1; jour <= 7; jour++)
          _LigneJour(
            jour: jour,
            creneaux: [
              for (final Creneau c in creneaux)
                if (c.jour == jour) c,
            ]..sort((a, b) => a.debut.compareTo(b.debut)),
            debutAxe: debutAxe,
            finAxe: finAxe,
            minuteNow: jour == maintenant.weekday ? minuteNow : null,
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            const SizedBox(width: 44),
            Text(
              Horaire.format(debutAxe),
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
            const Spacer(),
            Text(
              Horaire.format(finAxe),
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 100),
          ],
        ),
      ],
    );
  }
}

class _LigneJour extends StatelessWidget {
  const _LigneJour({
    required this.jour,
    required this.creneaux,
    required this.debutAxe,
    required this.finAxe,
    this.minuteNow,
  });

  final int jour;
  final List<Creneau> creneaux;
  final int debutAxe;
  final int finAxe;

  /// Renseigné seulement pour aujourd'hui.
  final int? minuteNow;

  @override
  Widget build(BuildContext context) {
    final int? now = minuteNow;
    final bool aujourdHui = now != null;
    final double etendue = (finAxe - debutAxe).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              Horaire.joursCourts[jour - 1],
              style: TextStyle(
                fontWeight: aujourdHui ? FontWeight.w800 : FontWeight.w600,
                color: aujourdHui ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final double w = box.maxWidth;
                double x(int minute) =>
                    ((minute - debutAxe) / etendue).clamp(0.0, 1.0) * w;
                return SizedBox(
                  height: 18,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 4,
                        height: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGrey,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      for (final Creneau c in creneaux)
                        Positioned(
                          left: x(c.debut),
                          width: x(c.fin) - x(c.debut),
                          top: 4,
                          height: 10,
                          child: Container(
                            decoration: BoxDecoration(
                              color: aujourdHui ? AppColors.primary : AppColors.secondary,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      if (now != null && now >= debutAxe && now <= finAxe)
                        Positioned(
                          left: x(now) - 1,
                          top: 0,
                          width: 2,
                          height: 18,
                          child: Container(color: AppColors.danger),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (creneaux.isEmpty)
                  const Text(
                    'Repos',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  )
                else
                  for (final Creneau c in creneaux)
                    Text(
                      c.libelle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: aujourdHui ? FontWeight.w700 : FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
