import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../models/utilisateur.dart';
import '../../domain/rdv_manager.dart';
import '../../domain/rdv_models.dart';
import '../../domain/rdv_permissions.dart';
import '../../domain/rdv_regles.dart';
import '../../services/calendrier_service.dart';
import '../../services/compte_rendu_pdf.dart';
import '../widgets/rdv_widgets.dart';
import 'appel_video_screen.dart';
import 'consultation_screen.dart';

/// Détail d'un rendez-vous + actions selon le rôle connecté.
class RdvDetailScreen extends StatefulWidget {
  const RdvDetailScreen({
    super.key,
    required this.rdvId,
    required this.utilisateur,
    this.messageInitial,
  });

  final int rdvId;
  final Utilisateur utilisateur;
  final String? messageInitial;

  @override
  State<RdvDetailScreen> createState() => _RdvDetailScreenState();
}

class _RdvDetailScreenState extends State<RdvDetailScreen> {
  final RdvManager _manager = RdvManager();

  RdvDetail? _detail;
  Consultation? _consultation;
  bool _chargement = true;
  bool _action = false;

  Utilisateur get _u => widget.utilisateur;

  @override
  void initState() {
    super.initState();
    _charger();
    final String? msg = widget.messageInitial;
    if (msg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          afficherInfo(context, msg);
        }
      });
    }
  }

  Future<void> _charger() async {
    final RdvDetail? d = await _manager.detail(widget.rdvId);
    final Consultation? c = await _manager.consultation(widget.rdvId);
    if (!mounted) {
      return;
    }
    setState(() {
      _detail = d;
      _consultation = c;
      _chargement = false;
    });
  }

  /// Exécute une action métier puis recharge l'écran.
  Future<void> _faire(Future<void> Function() action, String succes) async {
    setState(() => _action = true);
    try {
      await action();
      if (mounted) {
        afficherInfo(context, succes);
      }
    } catch (e) {
      if (mounted) {
        afficherErreur(context, e);
      }
    }
    await _charger();
    if (mounted) {
      setState(() => _action = false);
    }
  }

  Future<void> _annuler(RdvDetail d) async {
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Annuler le rendez-vous ?',
      message: '${RdvFormat.complet(d.rdv.dateHeure)} avec '
          '${_u.role == Role.patient ? d.medecinNom : d.patientNom}',
      confirmer: 'Annuler le RDV',
      danger: true,
    );
    if (ok) {
      await _faire(() => _manager.annuler(widget.rdvId, _u), 'Rendez-vous annulé');
    }
  }

  Future<void> _absent() async {
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Marquer le patient absent ?',
      message: 'Le RDV comptera dans le taux d\'absentéisme.',
      confirmer: 'Absent',
    );
    if (ok) {
      await _faire(() => _manager.marquerAbsent(widget.rdvId, _u), 'Patient marqué absent');
    }
  }

  Future<void> _rejoindreVisio(RdvDetail d) async {
    try {
      final String lien = await _manager.lienVisio(d);
      if (!mounted) {
        return;
      }
      final bool patient = _u.role == Role.patient;
      await AppelVideoScreen.ouvrir(
        context,
        lien: lien,
        nom: patient ? d.patientNom : d.medecinNom,
        titre: patient ? 'Téléconsultation · ${d.medecinNom}' : 'Téléconsultation · ${d.patientNom}',
      );
    } catch (e) {
      if (mounted) {
        afficherErreur(context, e);
      }
    }
  }

  Future<void> _agenda(RdvDetail d) async {
    try {
      final bool ok = await CalendrierService.ajouter(d);
      if (!mounted) {
        return;
      }
      if (!ok) {
        afficherInfo(context, "Impossible d'ouvrir Google Agenda");
      }
    } catch (e) {
      if (mounted) {
        afficherErreur(context, e);
      }
    }
  }

  Future<void> _ouvrirConsultation(RdvDetail d) async {
    // « Démarrer » passe le RDV en cours et note l'heure de début.
    if (d.rdv.statut == StatutRdv.confirme || d.rdv.statut == StatutRdv.enAttente) {
      try {
        await _manager.demarrer(widget.rdvId, _u);
      } catch (e) {
        if (mounted) {
          afficherErreur(context, e);
        }
        return;
      }
      if (d.rdv.type == TypeRdv.visio) {
        await _rejoindreVisio(d);
      }
    }
    if (!mounted) {
      return;
    }
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ConsultationScreen(rdvId: widget.rdvId, utilisateur: _u),
      ),
    );
    await _charger();
  }

  Future<void> _pdf(RdvDetail d, Consultation c) async {
    try {
      await CompteRenduPdf.partager(d, c);
    } catch (e) {
      if (mounted) {
        afficherErreur(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final RdvDetail? d = _detail;
    return Scaffold(
      appBar: AppBar(title: const Text('Rendez-vous')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : d == null
              ? const Center(child: Text('Rendez-vous introuvable'))
              : RefreshIndicator(
                  onRefresh: _charger,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _entete(d),
                      const SizedBox(height: 12),
                      _infos(d),
                      const SizedBox(height: 12),
                      if (_action) const LinearProgressIndicator(),
                      ..._actions(d),
                      ..._compteRendu(d),
                    ],
                  ),
                ),
    );
  }

  Widget _entete(RdvDetail d) {
    final RendezVous r = d.rdv;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: r.estUrgent
              ? const [Color(0xFFB4232A), AppColors.danger]
              : const [AppColors.primaryDark, AppColors.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r.type == TypeRdv.visio ? Icons.videocam_rounded : Icons.local_hospital_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                r.type.libelle,
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (r.estUrgent)
                const Text(
                  'URGENT',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            RdvFormat.jour(r.dateHeure),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            '${RdvFormat.heure(r.dateHeure)} - ${RdvFormat.heure(r.fin)} (${r.duree} min)',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _infos(RdvDetail d) {
    final RendezVous r = d.rdv;
    final String? annulation = r.motifAnnulation;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                StatutBadge(statut: r.statut),
                PrioriteBadge(priorite: r.priorite, alerte: d.alerteRecente),
              ],
            ),
            const SizedBox(height: 12),
            _ligne(Icons.person_rounded, 'Patient', d.patientNom),
            _ligne(
              Icons.medical_services_rounded,
              'Médecin',
              '${d.medecinNom}${d.specialite == null ? '' : ' · ${d.specialite}'}',
            ),
            if (d.serviceNom != null)
              _ligne(Icons.apartment_rounded, 'Service', d.serviceNom ?? ''),
            _ligne(Icons.edit_note_rounded, 'Motif', r.motif),
            if (d.alerteRecente)
              _ligne(
                Icons.monitor_heart_rounded,
                'Alerte',
                'Alerte de suivi vital reçue dans les dernières 48 h',
              ),
            if (r.statut == StatutRdv.annule && annulation != null)
              _ligne(Icons.info_outline_rounded, 'Annulation', annulation),
          ],
        ),
      ),
    );
  }

  Widget _ligne(IconData icon, String libelle, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(libelle, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(valeur, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(RdvDetail d) {
    final RendezVous r = d.rdv;
    final DateTime n = DateTime.now();
    final bool actif = r.statut.estActif;
    final bool estSonMedecin = _u.role == Role.medecin && _u.refId == r.medecinId;
    final bool estPatient = _u.role == Role.patient;
    final List<Widget> boutons = [];

    void ajouter(IconData icon, String libelle, VoidCallback? onTap, {Color? couleur}) {
      boutons.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          height: 50,
          child: FilledButton.tonalIcon(
            style: couleur == null
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: couleur.withValues(alpha: 0.12),
                    foregroundColor: couleur,
                  ),
            onPressed: _action ? null : onTap,
            icon: Icon(icon),
            label: Text(libelle),
          ),
        ),
      ));
    }

    // --- Médecin du RDV : consultation
    if (estSonMedecin && _u.role.consulter) {
      if (r.statut == StatutRdv.enAttente) {
        ajouter(Icons.check_rounded, 'Confirmer le rendez-vous',
            () => _faire(() => _manager.confirmer(widget.rdvId, _u), 'Rendez-vous confirmé'));
      }
      if (r.statut == StatutRdv.confirme || r.statut == StatutRdv.enAttente) {
        ajouter(
          Icons.play_arrow_rounded,
          r.type == TypeRdv.visio ? 'Démarrer la téléconsultation' : 'Démarrer la consultation',
          () => _ouvrirConsultation(d),
          couleur: AppColors.purple,
        );
      }
      if (r.statut == StatutRdv.enCours) {
        ajouter(Icons.edit_note_rounded, 'Continuer la consultation',
            () => _ouvrirConsultation(d),
            couleur: AppColors.purple);
      }
      if (r.statut == StatutRdv.termine) {
        ajouter(Icons.edit_rounded, 'Modifier le compte-rendu', () => _ouvrirConsultation(d));
      }
    }

    // --- Personnel (admin, infirmier, médecin) : statut
    if (_u.role.gererStatutRdv && !estSonMedecin && r.statut == StatutRdv.enAttente) {
      ajouter(Icons.check_rounded, 'Confirmer le rendez-vous',
          () => _faire(() => _manager.confirmer(widget.rdvId, _u), 'Rendez-vous confirmé'));
    }

    // --- Visio : patient et médecin du RDV
    if (r.type == TypeRdv.visio && actif && (estPatient || estSonMedecin)) {
      final bool bientot = r.dateHeure.difference(n) <= const Duration(minutes: 15);
      ajouter(
        Icons.videocam_rounded,
        bientot ? 'Rejoindre la visio' : 'Rejoindre la visio (ouvre 15 min avant)',
        bientot || estSonMedecin ? () => _rejoindreVisio(d) : null,
        couleur: AppColors.indigo,
      );
    }

    if (actif && (estPatient || estSonMedecin)) {
      ajouter(Icons.calendar_month_rounded, 'Ajouter à Google Agenda', () => _agenda(d));
    }

    if (_u.role.gererStatutRdv && RdvRegles.peutMarquerAbsent(r, n)) {
      ajouter(Icons.person_off_rounded, 'Marquer absent', _absent,
          couleur: AppColors.textSecondary);
    }

    if (actif && r.statut != StatutRdv.enCours) {
      final bool peut = _u.role.annulerSansDelai || RdvRegles.patientPeutAnnuler(r, n);
      ajouter(Icons.close_rounded, 'Annuler le rendez-vous', peut ? () => _annuler(d) : null,
          couleur: AppColors.danger);
      if (!peut) {
        boutons.add(const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Moins de 2 h avant le RDV : contactez le service pour annuler.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ));
      }
    }
    return boutons;
  }

  List<Widget> _compteRendu(RdvDetail d) {
    final Consultation? c = _consultation;
    if (c == null || d.rdv.statut != StatutRdv.termine) {
      return const [];
    }
    final String? resume = c.resumeIa;
    final bool patient = _u.role == Role.patient;
    return [
      const SizedBox(height: 8),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Compte-rendu',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  if (c.dureeReelle != null)
                    RdvBadge(
                      libelle: '${c.dureeReelle} min',
                      icon: Icons.timer_outlined,
                      couleur: AppColors.textSecondary,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (resume != null && resume.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text('Résumé', style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(resume),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Le patient voit le résumé ; le détail médical reste au personnel.
              if (!patient || resume == null || resume.isEmpty) ...[
                const Text('Diagnostic', style: TextStyle(color: AppColors.textSecondary)),
                Text(c.diagnostic, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Compte-rendu', style: TextStyle(color: AppColors.textSecondary)),
                Text(c.compteRendu),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: () => _pdf(d, c),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Compte-rendu PDF'),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
