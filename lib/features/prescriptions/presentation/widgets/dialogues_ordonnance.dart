import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../models/patient.dart';
import '../../data/medicament_repository.dart';
import '../../domain/formats_prescriptions.dart';
import '../../domain/models/medicament.dart';
import '../../domain/regles_ordonnance.dart';
import '../../domain/service_patients.dart';
import 'elements_ui.dart';

/// Demande le motif d'annulation (au moins 10 caractères).
/// Renvoie le motif, ou null si l'utilisateur renonce.
Future<String?> demanderMotif(
  BuildContext context, {
  required String titre,
  required String message,
  required String confirmer,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogueMotif(titre: titre, message: message, confirmer: confirmer),
  );
}

class _DialogueMotif extends StatefulWidget {
  const _DialogueMotif({required this.titre, required this.message, required this.confirmer});

  final String titre;
  final String message;
  final String confirmer;

  @override
  State<_DialogueMotif> createState() => _DialogueMotifState();
}

class _DialogueMotifState extends State<_DialogueMotif> {
  final TextEditingController _ctrl = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _valider() {
    final String? erreur = ReglesOrdonnance.motifAnnulation(_ctrl.text);
    if (erreur != null) {
      setState(() => _erreur = erreur);
      return;
    }
    Navigator.pop(context, _ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.message, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Motif',
              hintText: 'ex. erreur de posologie sur le Doliprane',
              errorText: _erreur,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: _valider,
          child: Text(widget.confirmer),
        ),
      ],
    );
  }
}

/// Liste de messages (contrôles avant validation).
/// [confirmer] null : simple information, sinon le médecin peut continuer.
Future<bool> afficherControles(
  BuildContext context, {
  required String titre,
  required List<String> messages,
  required bool bloquant,
  String? confirmer,
}) async {
  final bool? res = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      final Color couleur = bloquant ? AppColors.danger : AppColors.warning;
      return AlertDialog(
        icon: Icon(
          bloquant ? Icons.block_rounded : Icons.warning_amber_rounded,
          color: couleur,
        ),
        title: Text(titre),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final String m in messages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.circle, size: 8, color: couleur),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(m)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(confirmer == null ? 'Compris' : 'Retour'),
          ),
          if (confirmer != null)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmer),
            ),
        ],
      );
    },
  );
  return res ?? false;
}

/// Choix d'un patient du médecin (nouvelle ordonnance).
Future<Patient?> choisirPatient(BuildContext context, int medecinId) {
  return showModalBottomSheet<Patient>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ChoixPatient(medecinId: medecinId),
  );
}

class _ChoixPatient extends StatefulWidget {
  const _ChoixPatient({required this.medecinId});

  final int medecinId;

  @override
  State<_ChoixPatient> createState() => _ChoixPatientState();
}

class _ChoixPatientState extends State<_ChoixPatient> {
  List<Patient> _patients = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final List<Patient> res = await ServicePatients.instance.patientsDuMedecin(widget.medecinId);
    if (!mounted) {
      return;
    }
    setState(() {
      _patients = res;
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Pour quel patient ?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator())
                  : _patients.isEmpty
                      ? const EmptyState(
                          icon: Icons.people_outline,
                          message: "Vous n'êtes le médecin référent d'aucun patient",
                        )
                      : ListView.builder(
                          itemCount: _patients.length,
                          itemBuilder: (BuildContext context, int i) {
                            final Patient p = _patients[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.mint,
                                child: Text(
                                  '${p.prenom.isEmpty ? '' : p.prenom[0]}${p.nom.isEmpty ? '' : p.nom[0]}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              title: Text(p.nomComplet),
                              subtitle: Text('${p.age} ans · CIN ${p.cin}'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.pop(context, p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Choix d'un médicament actif du catalogue (ligne d'ordonnance).
Future<Medicament?> choisirMedicament(BuildContext context) {
  return showModalBottomSheet<Medicament>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ChoixMedicament(),
  );
}

class _ChoixMedicament extends StatefulWidget {
  const _ChoixMedicament();

  @override
  State<_ChoixMedicament> createState() => _ChoixMedicamentState();
}

class _ChoixMedicamentState extends State<_ChoixMedicament> {
  final MedicamentRepository _repo = MedicamentRepository();
  List<Medicament> _liste = [];
  String _texte = '';
  int _requete = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final int requete = ++_requete;
    final List<Medicament> res = await _repo.lister(texte: _texte);
    if (!mounted || requete != _requete) {
      return;
    }
    setState(() => _liste = res);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SearchField(
                  hint: 'Nom commercial ou DCI',
                  onChanged: (String v) {
                    _texte = v;
                    _charger();
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _liste.length,
                  itemBuilder: (BuildContext context, int i) {
                    final Medicament m = _liste[i];
                    return ListTile(
                      leading: Icon(StyleCategorie.iconeForme(m.forme), color: AppColors.primary),
                      title: Text(m.libelle),
                      subtitle: Text(
                        '${m.description}${m.generique ? ' · générique' : ''}',
                      ),
                      trailing: Text(
                        FormatsPrescriptions.dt(m.prixPublic),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () => Navigator.pop(context, m),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
