import 'package:flutter/material.dart';

import '../../../../../core/services/app_database.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/search_field.dart';
import '../../../../../models/patient.dart';
import '../../../domain/contrat_manager.dart';
import '../../../domain/models/apci.dart';
import '../../../domain/models/contrat_assurance.dart';
import '../../widgets/apci_patient_sheet.dart';
import '../../widgets/elements_ui.dart';
import '../apci_formulaire_screen.dart';

/// Onglet médecin — Formulaire APCI des patients.
///
/// Le médecin :
///  1. Voit la liste de ses patients avec leur statut APCI.
///  2. Sélectionne un patient pour consulter ses infos, déclarer / modifier
///     son APCI et générer le formulaire PDF CNAM.
class ApciFormulaireTab extends StatefulWidget {
  const ApciFormulaireTab({super.key, required this.medecinId});

  final int medecinId;

  @override
  State<ApciFormulaireTab> createState() => _ApciFormulaireTabState();
}

class _ApciFormulaireTabState extends State<ApciFormulaireTab> {
  final ContratManager _contratManager = ContratManager();

  List<_PatientApci> _patients = [];
  List<_PatientApci> _filtres = [];
  bool _chargement = true;
  String _texte = '';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);

    final db = await AppDatabase.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      'patients',
      where: 'medecin_id = ?',
      whereArgs: [widget.medecinId],
      orderBy: 'nom COLLATE NOCASE',
    );

    final List<_PatientApci> liste = [];
    for (final Map<String, Object?> r in rows) {
      final Patient p = Patient.fromMap(r);
      final Apci? apci =
          await _contratManager.apciDuPatient(p.id!);
      final ContratAssurance? contrat =
          await _contratManager.contratCnamActif(p.id!);
      liste.add(_PatientApci(
        patient: p,
        apci: apci,
        aContratCnam: contrat != null,
      ));
    }

    if (!mounted) return;
    setState(() {
      _patients = liste;
      _chargement = false;
      _filtrer();
    });
  }

  void _filtrer() {
    final String t = _texte.trim().toLowerCase();
    if (t.isEmpty) {
      _filtres = List.of(_patients);
    } else {
      _filtres = _patients.where((pa) {
        return pa.patient.nomComplet.toLowerCase().contains(t) ||
            pa.patient.cin.toLowerCase().contains(t) ||
            (pa.apci?.codeCim10.toLowerCase().contains(t) ?? false) ||
            (pa.apci?.libelle.toLowerCase().contains(t) ?? false);
      }).toList();
    }
  }

  Future<void> _ouvrirPatient(_PatientApci pa) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ApciFormulaireScreen(
          patientId: pa.patient.id!,
          medecinId: widget.medecinId,
        ),
      ),
    );
    // Recharger après retour (l'APCI a peut-être été modifiée)
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const EnTetePage(
            surtitre: 'Prise en charge à 100 %',
            titre: 'Formulaire APCI',
          ),

          // Barre de recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SearchField(
              hint: 'Nom, CIN ou code APCI',
              onChanged: (String v) {
                setState(() {
                  _texte = v;
                  _filtrer();
                });
              },
            ),
          ),
          const SizedBox(height: 8),

          // Compteurs résumé
          if (!_chargement)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  _PuceCompteur(
                    nb: _patients.length,
                    label: 'patient${_patients.length > 1 ? 's' : ''}',
                    couleur: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _PuceCompteur(
                    nb: _patients
                        .where((pa) => pa.apci != null)
                        .length,
                    label: 'APCI déclaré${_patients.where((pa) => pa.apci != null).length > 1 ? 'es' : 'e'}',
                    couleur: AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  _PuceCompteur(
                    nb: _patients
                        .where((pa) =>
                            pa.apci == null && pa.aContratCnam)
                        .length,
                    label: 'à déclarer',
                    couleur: AppColors.warning,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),

          // Liste
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _filtres.isEmpty
                    ? EmptyState(
                        icon: Icons.favorite_border_rounded,
                        message: _patients.isEmpty
                            ? 'Aucun patient affecté à ce médecin'
                            : 'Aucun résultat pour "$_texte"',
                      )
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              20, 4, 20, 120),
                          itemCount: _filtres.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder:
                              (BuildContext context, int i) {
                            return _CartePatientApci(
                              pa: _filtres[i],
                              onTap: () =>
                                  _ouvrirPatient(_filtres[i]),
                              onDeclarerRapide: _filtres[i].aContratCnam
                                  ? () => _declarerRapide(_filtres[i])
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

  /// Déclaration rapide depuis la liste (sans ouvrir le formulaire complet).
  Future<void> _declarerRapide(_PatientApci pa) async {
    final bool modifie = await afficherApciPatient(
        context, patientId: pa.patient.id!);
    if (modifie) _charger();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modèle local
// ─────────────────────────────────────────────────────────────────────────────

class _PatientApci {
  const _PatientApci({
    required this.patient,
    required this.apci,
    required this.aContratCnam,
  });

  final Patient patient;
  final Apci? apci;
  final bool aContratCnam;
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte patient
// ─────────────────────────────────────────────────────────────────────────────

class _CartePatientApci extends StatelessWidget {
  const _CartePatientApci({
    required this.pa,
    required this.onTap,
    this.onDeclarerRapide,
  });

  final _PatientApci pa;
  final VoidCallback onTap;
  final VoidCallback? onDeclarerRapide;

  @override
  Widget build(BuildContext context) {
    final Patient p = pa.patient;
    final Apci? apci = pa.apci;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête : nom + statut APCI
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      p.prenom.isNotEmpty
                          ? p.prenom[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
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
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'CIN ${p.cin} · ${p.age} ans · '
                          '${p.sexe == 'M' ? 'Homme' : 'Femme'}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Badge statut APCI
                  if (apci != null)
                    BadgeStatut(
                      libelle: apci.codeCim10,
                      icon: Icons.favorite_rounded,
                      couleur: AppColors.danger,
                    )
                  else if (pa.aContratCnam)
                    const BadgeStatut(
                      libelle: 'À déclarer',
                      icon: Icons.pending_rounded,
                      couleur: AppColors.warning,
                    )
                  else
                    const BadgeStatut(
                      libelle: 'Sans CNAM',
                      icon: Icons.shield_outlined,
                      couleur: AppColors.textSecondary,
                    ),
                ],
              ),

              // Détail APCI
              if (apci != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_rounded,
                          size: 14, color: AppColors.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${apci.codeCim10} — ${apci.libelle}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger),
                        ),
                      ),
                      const BadgeStatut(
                        libelle: '100 %',
                        icon: Icons.verified_rounded,
                        couleur: AppColors.success,
                      ),
                    ],
                  ),
                ),
              ],

              // Actions
              const SizedBox(height: 10),
              Row(
                children: [
                  // Bouton déclaration rapide
                  if (onDeclarerRapide != null)
                    OutlinedButton.icon(
                      onPressed: onDeclarerRapide,
                      icon: Icon(
                        apci == null
                            ? Icons.favorite_border_rounded
                            : Icons.edit_rounded,
                        size: 16,
                      ),
                      label: Text(
                          apci == null ? 'Déclarer APCI' : 'Modifier APCI'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  const Spacer(),
                  // Bouton formulaire PDF
                  FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.picture_as_pdf_rounded,
                        size: 16),
                    label: const Text('Formulaire PDF'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF006837),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget puce compteur
// ─────────────────────────────────────────────────────────────────────────────

class _PuceCompteur extends StatelessWidget {
  const _PuceCompteur({
    required this.nb,
    required this.label,
    required this.couleur,
  });

  final int nb;
  final String label;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$nb $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: couleur,
        ),
      ),
    );
  }
}
