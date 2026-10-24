import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/utilisateur.dart';
import '../../domain/rdv_manager.dart';
import '../../domain/rdv_models.dart';
import '../../domain/rdv_regles.dart';
import '../../services/compte_rendu_pdf.dart';
import '../../services/resume_ia_service.dart';
import '../widgets/rdv_widgets.dart';
import 'appel_video_screen.dart';

/// Rédaction de la consultation par le médecin (diagnostic, compte-rendu,
/// résumé IA) puis clôture du RDV. Renvoie true si quelque chose a changé.
class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({super.key, required this.rdvId, required this.utilisateur});

  final int rdvId;
  final Utilisateur utilisateur;

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final RdvManager _manager = RdvManager();
  final ResumeIaService _ia = ResumeIaService();
  final TextEditingController _diagnostic = TextEditingController();
  final TextEditingController _compteRendu = TextEditingController();
  final TextEditingController _resume = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  RdvDetail? _detail;
  DateTime? _debut;
  Timer? _timer;
  bool _chargement = true;
  bool _envoi = false;
  bool _generation = false;
  bool? _resumeParIa;
  bool _modifie = false;

  @override
  void initState() {
    super.initState();
    _charger();
    // Rafraîchit la durée écoulée affichée (« En cours depuis X min »).
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _diagnostic.dispose();
    _compteRendu.dispose();
    _resume.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final RdvDetail? d = await _manager.detail(widget.rdvId);
    final Consultation? c = await _manager.consultation(widget.rdvId);
    if (!mounted) {
      return;
    }
    setState(() {
      _detail = d;
      _debut = c?.debut;
      _diagnostic.text = c?.diagnostic ?? '';
      _compteRendu.text = c?.compteRendu ?? '';
      _resume.text = c?.resumeIa ?? '';
      _chargement = false;
    });
  }

  Future<void> _genererResume() async {
    final RdvDetail? d = _detail;
    if (d == null) {
      return;
    }
    if (_compteRendu.text.trim().length < 10) {
      afficherErreur(context, const RdvException('Rédigez d\'abord le compte-rendu'));
      return;
    }
    setState(() => _generation = true);
    final ResumeIa r = await _ia.resumer(
      motif: d.rdv.motif,
      diagnostic: _diagnostic.text,
      compteRendu: _compteRendu.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _resume.text = r.texte;
      _resumeParIa = r.ia;
      _generation = false;
    });
  }

  Future<void> _enregistrer({required bool terminer}) async {
    if (terminer && !(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _envoi = true);
    try {
      final Consultation c = await _manager.enregistrerConsultation(
        rdvId: widget.rdvId,
        diagnostic: _diagnostic.text,
        compteRendu: _compteRendu.text,
        resumeIa: _resume.text.trim().isEmpty ? null : _resume.text.trim(),
        terminer: terminer,
        u: widget.utilisateur,
      );
      _modifie = true;
      if (!mounted) {
        return;
      }
      setState(() => _envoi = false);
      if (!terminer) {
        afficherInfo(context, 'Brouillon enregistré');
        return;
      }
      await _proposerPdf(c);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _envoi = false);
      afficherErreur(context, e);
    }
  }

  Future<void> _proposerPdf(Consultation c) async {
    final RdvDetail? d = await _manager.detail(widget.rdvId);
    if (!mounted || d == null) {
      return;
    }
    final bool? pdf = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
        title: const Text('Consultation terminée'),
        content: Text('Durée réelle : ${c.dureeReelle ?? '-'} min.\n'
            'Le patient voit maintenant le compte-rendu dans son espace.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('PDF'),
          ),
        ],
      ),
    );
    if (pdf == true) {
      try {
        await CompteRenduPdf.partager(d, c);
      } catch (e) {
        if (mounted) {
          afficherErreur(context, e);
        }
      }
    }
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final RdvDetail? d = _detail;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          Navigator.pop(context, _modifie);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Consultation')),
        body: _chargement
            ? const Center(child: CircularProgressIndicator())
            : d == null
                ? const Center(child: Text('Rendez-vous introuvable'))
                : Form(
                    key: _form,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        _bandeau(d),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _diagnostic,
                          label: 'Diagnostic',
                          icon: Icons.biotech_rounded,
                          hint: 'Ex : hypertension artérielle grade 1',
                          textCapitalization: TextCapitalization.sentences,
                          validator: (String? v) => (v == null || v.trim().isEmpty)
                              ? 'Le diagnostic est obligatoire'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _compteRendu,
                          label: 'Compte-rendu',
                          icon: Icons.description_outlined,
                          hint: 'Examen, constantes, traitement, conseils, suivi...',
                          maxLines: 8,
                          textCapitalization: TextCapitalization.sentences,
                          validator: (String? v) => (v == null || v.trim().length < 10)
                              ? 'Compte-rendu trop court (10 caractères minimum)'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Résumé pour le patient',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _generation ? null : _genererResume,
                              icon: _generation
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.bolt_rounded),
                              label: const Text('Générer (IA)'),
                            ),
                          ],
                        ),
                        if (_resumeParIa != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              _resumeParIa == true
                                  ? 'Généré par Gemini : relisez avant de valider.'
                                  : 'Clé Gemini absente : résumé local. Vous pouvez le modifier.',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        AppTextField(
                          controller: _resume,
                          label: 'Résumé (modifiable)',
                          icon: Icons.short_text_rounded,
                          maxLines: 6,
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: 'Terminer la consultation',
                          icon: Icons.check_circle_rounded,
                          loading: _envoi,
                          onPressed: () => _enregistrer(terminer: true),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _envoi ? null : () => _enregistrer(terminer: false),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Enregistrer le brouillon'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _bandeau(RdvDetail d) {
    final DateTime? debut = _debut;
    final String? lien = d.rdv.lienVisio;
    final int ecoule = debut == null ? 0 : DateTime.now().difference(debut).inMinutes;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d.patientNom,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              '${RdvFormat.complet(d.rdv.dateHeure)} · ${d.rdv.motif}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TypeBadge(type: d.rdv.type),
                PrioriteBadge(priorite: d.rdv.priorite, alerte: d.alerteRecente),
                if (debut != null && d.rdv.statut == StatutRdv.enCours)
                  RdvBadge(
                    libelle: 'En cours depuis $ecoule min',
                    icon: Icons.timer_outlined,
                    couleur: AppColors.purple,
                  ),
                if (d.rdv.type == TypeRdv.visio && lien != null)
                  ActionChip(
                    avatar: const Icon(Icons.videocam_rounded, size: 16),
                    label: const Text('Rouvrir la visio'),
                    onPressed: () => AppelVideoScreen.ouvrir(
                      context,
                      lien: lien,
                      nom: d.medecinNom,
                      titre: 'Téléconsultation · ${d.patientNom}',
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
