import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/patient.dart';
import '../../../../models/utilisateur.dart';
import '../../domain/rdv_manager.dart';
import '../../domain/rdv_models.dart';
import '../widgets/rdv_widgets.dart';
import 'rdv_detail_screen.dart';

/// Demande de consultation urgente (NON vitale).
/// Urgence vitale -> bouton SOS / ambulance (module 3), pas un RDV.
class DemandeUrgenteScreen extends StatefulWidget {
  const DemandeUrgenteScreen({super.key, required this.utilisateur});

  final Utilisateur utilisateur;

  @override
  State<DemandeUrgenteScreen> createState() => _DemandeUrgenteScreenState();
}

class _DemandeUrgenteScreenState extends State<DemandeUrgenteScreen> {
  final RdvManager _manager = RdvManager();
  final TextEditingController _motif = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  List<Patient> _patients = [];
  int? _patientId;
  TypeRdv _type = TypeRdv.visio;
  bool _envoi = false;

  bool get _estPatient => widget.utilisateur.role == Role.patient;

  @override
  void initState() {
    super.initState();
    if (_estPatient) {
      _patientId = widget.utilisateur.refId;
    } else {
      _manager.patients(widget.utilisateur).then((List<Patient> p) {
        if (mounted) {
          setState(() => _patients = p);
        }
      });
    }
  }

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final int? pid = _patientId;
    if (pid == null) {
      afficherErreur(context, const RdvException('Choisissez le patient'));
      return;
    }
    setState(() => _envoi = true);
    try {
      final RdvDetail d = await _manager.demandeUrgente(
        patientId: pid,
        type: _type,
        motif: _motif.text,
        auteur: widget.utilisateur,
      );
      if (!mounted) {
        return;
      }
      // On remplace cet écran par le détail du RDV créé.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => RdvDetailScreen(
            rdvId: d.rdv.id ?? 0,
            utilisateur: widget.utilisateur,
            messageInitial: 'Pris en charge par ${d.medecinNom} '
                '${_type == TypeRdv.visio ? '- rejoignez la visio' : '- présentez-vous au service'}',
          ),
        ),
        result: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _envoi = false);
      afficherErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultation urgente')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Malaise, douleur thoracique forte, difficulté à respirer ?\n'
                      "N'attendez pas : utilisez le bouton SOS ou appelez le 190 (SAMU).\n\n"
                      'Cette demande est pour un problème urgent mais non vital : '
                      'un médecin vous prend en priorité.',
                      style: TextStyle(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
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
                onChanged: (int? v) => setState(() => _patientId = v),
              ),
              const SizedBox(height: 14),
            ],
            SegmentedButton<TypeRdv>(
              segments: const [
                ButtonSegment<TypeRdv>(
                  value: TypeRdv.visio,
                  icon: Icon(Icons.videocam_rounded),
                  label: Text('Visio immédiate'),
                ),
                ButtonSegment<TypeRdv>(
                  value: TypeRdv.presentiel,
                  icon: Icon(Icons.local_hospital_rounded),
                  label: Text("Aujourd'hui"),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (Set<TypeRdv> s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 6),
            Text(
              _type == TypeRdv.visio
                  ? 'Un médecin disponible vous rejoint en visio dans les prochaines minutes.'
                  : 'Vous êtes placé sur le premier horaire libre du jour, en tête de file.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _motif,
              label: 'Que se passe-t-il ?',
              icon: Icons.edit_note_rounded,
              hint: 'Ex : fièvre à 39 depuis hier, alerte tension reçue...',
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              validator: (String? v) => (v == null || v.trim().length < 3)
                  ? 'Décrivez brièvement le problème'
                  : null,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Envoyer la demande urgente',
              icon: Icons.emergency_rounded,
              loading: _envoi,
              onPressed: _envoyer,
            ),
          ],
        ),
      ),
    );
  }
}
