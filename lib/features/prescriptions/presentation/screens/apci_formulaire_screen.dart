import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/services/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/medecin.dart';
import '../../../../models/patient.dart';
import '../../data/apci_repository.dart';
import '../../domain/contrat_manager.dart';
import '../../domain/models/apci.dart';
import '../../domain/models/contrat_assurance.dart';
import '../pdf/apci_formulaire_pdf.dart';
import '../widgets/apci_patient_sheet.dart';
import '../widgets/elements_ui.dart';

/// Écran médecin : récapitulatif complet des informations patient nécessaires
/// pour le formulaire APCI CNAM, avec génération et impression du PDF.
///
/// Accès : depuis l'onglet APCI (bouton ♡ PDF) ou depuis la fiche ordonnance.
class ApciFormulaireScreen extends StatefulWidget {
  const ApciFormulaireScreen({
    super.key,
    required this.patientId,
    required this.medecinId,
  });

  final int patientId;
  final int medecinId;

  @override
  State<ApciFormulaireScreen> createState() => _ApciFormulaireScreenState();
}

class _ApciFormulaireScreenState extends State<ApciFormulaireScreen> {
  final ContratManager _contratManager = ContratManager();
  final ApciRepository _apciRepo = ApciRepository();

  Patient? _patient;
  Medecin? _medecin;
  Apci? _apci;
  ContratAssurance? _contratCnam;
  List<String> _medicaments = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final db = await AppDatabase.instance.database;

      // Patient
      final List<Map<String, Object?>> pRows = await db.query(
        'patients',
        where: 'id = ?',
        whereArgs: [widget.patientId],
        limit: 1,
      );
      final Patient? patient =
          pRows.isEmpty ? null : Patient.fromMap(pRows.first);

      // Médecin
      final List<Map<String, Object?>> mRows = await db.query(
        'medecins',
        where: 'id = ?',
        whereArgs: [widget.medecinId],
        limit: 1,
      );
      final Medecin? medecin =
          mRows.isEmpty ? null : Medecin.fromMap(mRows.first);

      // APCI et contrat
      final Apci? apci =
          await _contratManager.apciDuPatient(widget.patientId);
      final ContratAssurance? contrat =
          await _contratManager.contratCnamActif(widget.patientId);
      List<String> medicaments = [];
      if (apci != null) {
        medicaments = await _apciRepo.dcis(apci.codeCim10);
      }

      if (!mounted) return;
      setState(() {
        _patient = patient;
        _medecin = medecin;
        _apci = apci;
        _contratCnam = contrat;
        _medicaments = medicaments;
        _chargement = false;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.toString();
        _chargement = false;
      });
    }
  }

  DonneesFormulaireApci _donnees() {
    final Patient p = _patient!;
    final Medecin m = _medecin!;
    return DonneesFormulaireApci(
      nomPatient: p.nom,
      prenomPatient: p.prenom,
      dateNaissance: Formatters.date(p.dateNaissance),
      cin: p.cin,
      telephone: p.telephone,
      adresse: p.adresse,
      sexe: p.sexe,
      numeroAdherent: _contratCnam?.numeroAdherent ?? '',
      filiere: _contratCnam?.filiere,
      apci: _apci,
      medicamentsCouvrerts: _medicaments,
      nomMedecin: m.nomComplet,
      specialiteMedecin: m.specialite,
      matriculeMedecin: m.matricule,
      telephoneMedecin: m.telephone,
      dateFormulaire: DateTime.now(),
    );
  }

  void _imprimer() {
    if (_patient == null || _medecin == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _PdfPreviewScreen(donnees: _donnees()),
      ),
    );
  }

  /// Ouvre la bottom sheet de déclaration APCI, puis recharge les données.
  Future<void> _declarerApci() async {
    final bool modifie =
        await afficherApciPatient(context, patientId: widget.patientId);
    if (modifie) {
      _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulaire APCI CNAM'),
        actions: [
          if (!_chargement && _patient != null)
            IconButton(
              tooltip: 'Générer le PDF',
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: _imprimer,
            ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _erreur!,
                      style: const TextStyle(color: AppColors.danger),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _corps(),
      floatingActionButton: (!_chargement && _patient != null)
          ? FloatingActionButton.extended(
              onPressed: _imprimer,
              icon: const Icon(Icons.print_rounded),
              label: const Text('Imprimer / Partager le PDF'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _corps() {
    final Patient? p = _patient;
    final Medecin? m = _medecin;
    if (p == null || m == null) {
      return const Center(child: Text('Données introuvables'));
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // Bandeau information avec étapes claires
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF006837).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF006837).withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_rounded,
                        color: Color(0xFF006837), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Comment remplir le formulaire APCI ?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF006837),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _EtapeGuide(
                    num: '1',
                    texte: 'Vérifiez les informations du patient ci-dessous '
                        '(CIN, date de naissance, adresse, N° adhérent CNAM).',
                    couleur: AppColors.primary),
                const SizedBox(height: 6),
                _EtapeGuide(
                    num: '2',
                    texte: 'Déclarez ou modifiez l\'APCI du patient '
                        '(maladie prise en charge à 100 %) dans la section APCI.',
                    couleur: AppColors.danger),
                const SizedBox(height: 6),
                _EtapeGuide(
                    num: '3',
                    texte: 'Appuyez sur "Générer et imprimer le formulaire PDF" '
                        'pour obtenir le document pré-rempli prêt à signer.',
                    couleur: const Color(0xFF006837)),
                const SizedBox(height: 6),
                _EtapeGuide(
                    num: '4',
                    texte: 'Signez et tamponnez votre partie. '
                        'Le pharmacien complètera la liste des médicaments.',
                    couleur: AppColors.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ---- Informations patient ----
          _SectionTitre(
            titre: 'Informations patient',
            icon: Icons.person_rounded,
            couleur: AppColors.primary,
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _LigneInfo('Nom', p.nom),
                  _LigneInfo('Prénom', p.prenom),
                  _LigneInfo(
                      'Date de naissance', Formatters.date(p.dateNaissance)),
                  _LigneInfo('Âge', '${p.age} ans'),
                  _LigneInfo(
                      'Sexe', p.sexe == 'M' ? 'Masculin' : 'Féminin'),
                  _LigneInfo('CIN', p.cin),
                  _LigneInfo('Téléphone', p.telephone),
                  _LigneInfo('Adresse', p.adresse.isEmpty ? '—' : p.adresse),
                  if (p.groupeSanguin != null)
                    _LigneInfo('Groupe sanguin', p.groupeSanguin!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ---- Contrat CNAM ----
          _SectionTitre(
            titre: 'Contrat CNAM',
            icon: Icons.shield_rounded,
            couleur: const Color(0xFF006837),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _contratCnam == null
                  ? Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Aucun contrat CNAM actif. L\'administrateur doit '
                            'créer le contrat dans la fiche du patient.',
                            style: TextStyle(
                                color: AppColors.warning.withValues(alpha: 0.9),
                                fontSize: 13),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _LigneInfo(
                            'N° adhérent', _contratCnam!.numeroAdherent),
                        _LigneInfo(
                          'Filière',
                          _contratCnam!.filiere?.libelle ?? '(non renseignée)',
                        ),
                        _LigneInfo(
                          'Bénéficiaire',
                          _contratCnam!.beneficiaire.libelle,
                        ),
                        _LigneInfo(
                          'Début',
                          Formatters.date(_contratCnam!.dateDebut),
                        ),
                        if (_contratCnam!.dateFin != null)
                          _LigneInfo(
                            'Fin',
                            Formatters.date(_contratCnam!.dateFin!),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // ---- APCI déclarée ----
          Row(
            children: [
              const _SectionTitre(
                titre: 'APCI — Maladie prise en charge à 100 %',
                icon: Icons.favorite_rounded,
                couleur: AppColors.danger,
              ),
              const Spacer(),
              // Bouton déclarer / modifier l'APCI directement ici
              if (_contratCnam != null)
                TextButton.icon(
                  onPressed: _declarerApci,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(_apci == null ? 'Déclarer' : 'Modifier'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _apci == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppColors.textSecondary, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Aucune APCI déclarée pour ce patient.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        if (_contratCnam != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _declarerApci,
                            icon: const Icon(Icons.favorite_border_rounded,
                                color: AppColors.danger),
                            label: const Text('Déclarer l\'APCI du patient'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(
                                  color: AppColors.danger),
                            ),
                          ),
                        ] else
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Un contrat CNAM actif est requis. '
                              'L\'administrateur doit créer le contrat dans '
                              'la fiche du patient.',
                              style: TextStyle(
                                  color: AppColors.warning, fontSize: 12),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _apci!.codeCim10,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _apci!.libelle,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const BadgeStatut(
                              libelle: '100 %',
                              icon: Icons.verified_rounded,
                              couleur: AppColors.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Déclarée par le médecin · Prise en charge CNAM à 100 %',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _declarerApci,
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text('Modifier l\'APCI'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(
                                    color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // ---- Médicaments couverts (tenus par le pharmacien) ----
          _SectionTitre(
            titre: 'Médicaments couverts (liste pharmacien)',
            icon: Icons.medication_rounded,
            couleur: AppColors.primary,
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _medicaments.isEmpty
                  ? const Text(
                      'Aucun médicament enregistré pour cette APCI. '
                      'Le pharmacien les renseignera directement sur le formulaire imprimé.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_medicaments.length} médicament${_medicaments.length > 1 ? 's' : ''} '
                          'pré-rempli${_medicaments.length > 1 ? 's' : ''} dans le PDF',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final String dci in _medicaments)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  dci,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // ---- Médecin prescripteur ----
          _SectionTitre(
            titre: 'Médecin prescripteur',
            icon: Icons.medical_services_rounded,
            couleur: AppColors.primary,
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _LigneInfo('Nom', m.nomComplet),
                  _LigneInfo('Spécialité', m.specialite),
                  _LigneInfo('Matricule', m.matricule),
                  _LigneInfo('Téléphone', m.telephone),
                  _LigneInfo('Email', m.email),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // ---- Bouton principal ----
          FilledButton.icon(
            onPressed: _imprimer,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Générer et imprimer le formulaire PDF'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF006837),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Le document PDF sera pré-rempli avec toutes les informations '
            'ci-dessus. Le médecin et le pharmacien signeront et compléteront '
            'chacun leur partie sur le document imprimé.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Écran d'aperçu / impression PDF
// ============================================================================

class _PdfPreviewScreen extends StatelessWidget {
  const _PdfPreviewScreen({required this.donnees});

  final DonneesFormulaireApci donnees;

  @override
  Widget build(BuildContext context) {
    final String nom =
        'APCI_CNAM_${donnees.nomPatient}_${donnees.prenomPatient}.pdf'
            .replaceAll(' ', '_');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulaire APCI CNAM'),
        actions: [
          IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: PdfPreview(
        build: (PdfPageFormat format) =>
            ApciFormulairePdf.generer(donnees),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: nom,
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}

// ============================================================================
// Widgets utilitaires
// ============================================================================

class _SectionTitre extends StatelessWidget {
  const _SectionTitre({
    required this.titre,
    required this.icon,
    required this.couleur,
  });

  final String titre;
  final IconData icon;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: couleur),
        const SizedBox(width: 8),
        Text(
          titre,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: couleur,
          ),
        ),
      ],
    );
  }
}

class _LigneInfo extends StatelessWidget {
  const _LigneInfo(this.label, this.valeur);

  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              valeur,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Étape numérotée dans le guide.
class _EtapeGuide extends StatelessWidget {
  const _EtapeGuide({
    required this.num,
    required this.texte,
    required this.couleur,
  });

  final String num;
  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: couleur,
            shape: BoxShape.circle,
          ),
          child: Text(
            num,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texte,
            style: TextStyle(fontSize: 12, color: couleur),
          ),
        ),
      ],
    );
  }
}
