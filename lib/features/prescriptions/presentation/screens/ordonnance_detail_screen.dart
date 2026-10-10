import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/ordonnance_repository.dart';
import '../../domain/authenticite_ordonnance.dart';
import '../../domain/models/ligne_ordonnance.dart';
import '../../domain/models/ordonnance.dart';
import '../../domain/models/vues_ordonnance.dart';
import '../../domain/ordonnance_manager.dart';
import '../../domain/posologie.dart';
import '../../domain/prescriptions_exception.dart';
import '../../domain/regles_ordonnance.dart';
import '../../domain/remboursement_manager.dart';
import '../widgets/detail_prise_en_charge.dart';
import '../widgets/dialogues_ordonnance.dart';
import '../widgets/elements_ui.dart';
import 'dossier_detail_screen.dart';
import 'ligne_form_screen.dart';
import 'ordonnance_pdf_screen.dart';

/// Fiche d'une ordonnance. Les actions dépendent du statut :
/// brouillon (lignes, validité, validation) ; validée (annuler, corriger) ;
/// délivrée ou expirée (renouveler).
class OrdonnanceDetailScreen extends StatefulWidget {
  const OrdonnanceDetailScreen({
    super.key,
    required this.ordonnanceId,
    this.lectureSeule = false,
    this.modePatient = false,
  });

  final int ordonnanceId;

  /// true pour un profil qui consulte sans prescrire.
  final bool lectureSeule;

  /// Espace du patient : QR code, simulation, renouvellement, dossier.
  final bool modePatient;

  @override
  State<OrdonnanceDetailScreen> createState() => _OrdonnanceDetailScreenState();
}

class _OrdonnanceDetailScreenState extends State<OrdonnanceDetailScreen> {
  final OrdonnanceRepository _repo = OrdonnanceRepository();
  final OrdonnanceManager _manager = OrdonnanceManager();
  final RemboursementManager _remboursement = RemboursementManager();

  OrdonnanceResume? _resume;
  List<LigneDetail> _lignes = [];
  bool _chargement = true;
  bool _occupe = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final OrdonnanceResume? r = await _repo.resume(widget.ordonnanceId);
    final List<LigneDetail> lignes = await _manager.lignesDetaillees(widget.ordonnanceId);
    if (!mounted) {
      return;
    }
    setState(() {
      _resume = r;
      _lignes = lignes;
      _chargement = false;
    });
  }

  /// Lance une action métier ; une PrescriptionsException s'affiche en bandeau.
  Future<void> _executer(Future<void> Function() action) async {
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      await action();
    } on PrescriptionsException catch (e) {
      if (mounted) {
        setState(() => _erreur = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _occupe = false);
      }
    }
    await _charger();
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  // ----- Brouillon -----

  Future<void> _ouvrirLigne(Ordonnance o, [LigneDetail? ligne]) async {
    final bool? modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => LigneFormScreen(ordonnance: o, ligne: ligne)),
    );
    if (modifie == true) {
      _charger();
    }
  }

  Future<void> _supprimerLigne(Ordonnance o, LigneDetail d) async {
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Retirer ${d.medicament.libelle} ?',
      message: "La ligne sera retirée de l'ordonnance.",
      confirmer: 'Retirer',
      danger: true,
    );
    if (ok) {
      await _executer(() => _manager.supprimerLigne(o, d.ligne.id!));
    }
  }

  Future<void> _changerExpiration(Ordonnance o) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: o.dateExpiration,
      firstDate: o.dateEmission.add(const Duration(days: 1)),
      lastDate: o.dateEmission.add(const Duration(days: 365)),
      helpText: "Valable jusqu'au",
    );
    if (date == null) {
      return;
    }
    await _executer(() => _manager.modifierEnTete(_avecEnTete(o, expiration: date)));
  }

  Future<void> _changerRenouvellements(Ordonnance o, int nb) async {
    await _executer(() => _manager.modifierEnTete(_avecEnTete(o, renouvellements: nb)));
  }

  Ordonnance _avecEnTete(Ordonnance o, {DateTime? expiration, int? renouvellements}) {
    return Ordonnance(
      id: o.id,
      numero: o.numero,
      patientId: o.patientId,
      medecinId: o.medecinId,
      consultationId: o.consultationId,
      dateEmission: o.dateEmission,
      dateExpiration: expiration ?? o.dateExpiration,
      nbRenouvellements: renouvellements ?? o.nbRenouvellements,
      ordonnanceOrigineId: o.ordonnanceOrigineId,
    );
  }

  Future<void> _supprimerBrouillon(Ordonnance o) async {
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Supprimer le brouillon ?',
      message: '${o.numero} et ses lignes seront supprimés.',
      confirmer: 'Supprimer',
      danger: true,
    );
    if (!ok) {
      return;
    }
    try {
      await _manager.supprimerBrouillon(o);
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } on PrescriptionsException catch (e) {
      if (mounted) {
        setState(() => _erreur = e.message);
      }
    }
  }

  Future<void> _valider(Ordonnance o) async {
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    final ControleValidation controle = await _manager.controlerValidation(o);
    if (!mounted) {
      return;
    }
    setState(() => _occupe = false);

    if (!controle.peutValider) {
      await afficherControles(
        context,
        titre: 'Validation impossible',
        messages: controle.bloquants,
        bloquant: true,
      );
      return;
    }
    final bool ok = controle.avertissements.isEmpty
        ? await showConfirmDialog(
            context,
            titre: "Valider l'ordonnance ?",
            message: "Après validation, elle est signée et verrouillée : elle ne pourra "
                "plus être modifiée, seulement annulée.",
            confirmer: 'Valider',
          )
        : await afficherControles(
            context,
            titre: 'À vérifier avant de valider',
            messages: controle.avertissements,
            bloquant: false,
            confirmer: 'Valider quand même',
          );
    if (!ok) {
      return;
    }

    int nbPrises = 0;
    await _executer(() async {
      nbPrises = await _manager.valider(o);
    });
    if (mounted && _erreur == null) {
      _message('Ordonnance validée · $nbPrises prises planifiées');
    }
  }

  // ----- Après validation -----

  Future<void> _annuler(Ordonnance o) async {
    final String? motif = await demanderMotif(
      context,
      titre: 'Annuler ${o.numero} ?',
      message: "L'ordonnance reste dans l'historique avec son motif. "
          'Les prises prévues ne seront plus proposées au patient.',
      confirmer: "Annuler l'ordonnance",
    );
    if (motif == null) {
      return;
    }
    await _executer(() => _manager.annuler(o, motif));
    if (mounted && _erreur == null) {
      _message('Ordonnance annulée');
    }
  }

  Future<void> _corriger(Ordonnance o) async {
    final String? motif = await demanderMotif(
      context,
      titre: 'Corriger ${o.numero} ?',
      message: "L'ordonnance est annulée avec ce motif, puis une copie en brouillon "
          'est créée pour la corriger.',
      confirmer: 'Annuler et corriger',
    );
    if (motif == null) {
      return;
    }
    int? copie;
    await _executer(() async {
      copie = await _manager.corriger(o, motif);
    });
    _ouvrirCopie(copie, 'Brouillon de correction créé');
  }

  Future<void> _renouveler(Ordonnance o) async {
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Renouveler ${o.numero} ?',
      message: "Une nouvelle ordonnance validée, datée d'aujourd'hui, reprend les mêmes "
          'médicaments. Il restera ${o.nbRenouvellements - 1} renouvellement(s).',
      confirmer: 'Renouveler',
    );
    if (!ok) {
      return;
    }
    int? copie;
    await _executer(() async {
      copie = await _manager.renouveler(o);
    });
    _ouvrirCopie(copie, 'Ordonnance renouvelée');
  }

  void _ouvrirCopie(int? copieId, String texte) {
    if (copieId == null || !mounted) {
      return;
    }
    _message(texte);
    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OrdonnanceDetailScreen(
          ordonnanceId: copieId,
          lectureSeule: widget.lectureSeule,
          modePatient: widget.modePatient,
        ),
      ),
    );
  }

  // ----- PDF, patient -----

  void _ouvrirPdf(Ordonnance o) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => OrdonnancePdfScreen(ordonnanceId: o.id!)),
    );
  }

  void _simuler(Ordonnance o) {
    afficherSimulation(
      context,
      titre: 'Combien je vais payer ?',
      calcul: _remboursement.calculer(o, simulation: true),
    );
  }

  Future<void> _creerDossier(Ordonnance o) async {
    int? id;
    await _executer(() async {
      id = await _remboursement.creerDossier(o);
    });
    final int? dossierId = id;
    if (dossierId == null || !mounted) {
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => DossierDetailScreen(dossierId: dossierId, admin: false)),
    );
  }

  List<Widget> _actionsPatient(Ordonnance o) {
    final List<Widget> res = [];
    void ajouter(Widget w) {
      res.add(w);
      res.add(const SizedBox(height: 10));
    }

    if (o.statut.estActive) {
      ajouter(PrimaryButton(
        label: 'Montrer au pharmacien (QR code)',
        icon: Icons.qr_code_2_rounded,
        onPressed: () => _ouvrirPdf(o),
      ));
      ajouter(SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () => _simuler(o),
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Combien je vais payer ?'),
        ),
      ));
    }
    if (o.statut == StatutOrdonnance.delivree || o.statut == StatutOrdonnance.partiellementDelivree) {
      ajouter(SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _occupe ? null : () => _creerDossier(o),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Créer le dossier de remboursement'),
        ),
      ));
    }
    if (OrdonnanceManager.estRenouvelable(o)) {
      ajouter(PrimaryButton(
        label: 'Renouveler (${o.nbRenouvellements} restant${o.nbRenouvellements > 1 ? 's' : ''})',
        icon: Icons.autorenew_rounded,
        loading: _occupe,
        onPressed: () => _renouveler(o),
      ));
    }
    return res;
  }

  // ----- Affichage -----

  @override
  Widget build(BuildContext context) {
    final OrdonnanceResume? r = _resume;
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Ordonnance introuvable')),
      );
    }

    final Ordonnance o = r.ordonnance;
    final bool modifiable = o.estModifiable && !widget.lectureSeule;

    return Scaffold(
      appBar: AppBar(
        title: Text(o.numero),
        actions: [
          if (!o.estModifiable)
            IconButton(
              icon: const Icon(Icons.qr_code_2_rounded),
              tooltip: 'QR code et PDF',
              onPressed: () => _ouvrirPdf(o),
            ),
          if (modifiable)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              tooltip: 'Supprimer le brouillon',
              onPressed: _occupe ? null : () => _supprimerBrouillon(o),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _EnTete(resume: r, lignes: _lignes),
            const SizedBox(height: 12),
            if (modifiable) ...[
              _Validite(
                ordonnance: o,
                occupe: _occupe,
                onExpiration: () => _changerExpiration(o),
                onRenouvellements: (int nb) => _changerRenouvellements(o, nb),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Médicaments (${_lignes.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (modifiable)
                  TextButton.icon(
                    onPressed: _occupe ? null : () => _ouvrirLigne(o),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Ajouter'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_lignes.isEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  onTap: modifiable && !_occupe ? () => _ouvrirLigne(o) : null,
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.medication_outlined, size: 40, color: AppColors.textSecondary),
                        SizedBox(height: 8),
                        Text(
                          'Aucun médicament pour le moment',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              for (final LigneDetail d in _lignes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CarteLigne(
                    detail: d,
                    brouillon: o.estModifiable,
                    onTap: modifiable && !_occupe ? () => _ouvrirLigne(o, d) : null,
                    onSupprimer: modifiable && !_occupe ? () => _supprimerLigne(o, d) : null,
                  ),
                ),
            const SizedBox(height: 8),
            if (_erreur != null) ...[
              ErrorBanner(message: _erreur!),
              const SizedBox(height: 12),
            ],
            if (!widget.lectureSeule) ..._actions(o),
            if (widget.modePatient) ..._actionsPatient(o),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(Ordonnance o) {
    if (o.estModifiable) {
      return [
        PrimaryButton(
          label: "Valider l'ordonnance",
          icon: Icons.verified_rounded,
          loading: _occupe,
          onPressed: () => _valider(o),
        ),
      ];
    }
    final List<Widget> res = [];
    if (OrdonnanceManager.estRenouvelable(o)) {
      res.add(PrimaryButton(
        label: 'Renouveler',
        icon: Icons.autorenew_rounded,
        loading: _occupe,
        onPressed: () => _renouveler(o),
      ));
      res.add(const SizedBox(height: 10));
    }
    if (OrdonnanceManager.estAnnulable(o.statut)) {
      res.add(SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _occupe ? null : () => _corriger(o),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Corriger (annuler puis copier en brouillon)'),
        ),
      ));
      res.add(const SizedBox(height: 10));
      res.add(SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: _occupe ? null : () => _annuler(o),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text("Annuler l'ordonnance"),
        ),
      ));
    }
    return res;
  }
}

/// Carte d'en-tête : patient, médecin, dates, statut, signature.
class _EnTete extends StatelessWidget {
  const _EnTete({required this.resume, required this.lignes});

  final OrdonnanceResume resume;
  final List<LigneDetail> lignes;

  @override
  Widget build(BuildContext context) {
    final Ordonnance o = resume.ordonnance;
    final String? hash = o.hashSignature;
    final String? origine = resume.origineNumero;
    final String? motif = o.motifAnnulation;

    final List<LigneOrdonnance> brutes = [];
    for (final LigneDetail d in lignes) {
      brutes.add(d.ligne);
    }
    final bool signatureValide = hash != null && AuthenticiteOrdonnance.verifier(o, brutes);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    resume.patientNom,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                StyleStatut.badge(o.statut),
              ],
            ),
            const SizedBox(height: 4),
            Text(resume.medecinNom, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                InfoLigne(icon: Icons.event_outlined, texte: 'Émise le ${Formatters.date(o.dateEmission)}'),
                InfoLigne(
                  icon: Icons.event_available_outlined,
                  texte: "Valable jusqu'au ${Formatters.date(o.dateExpiration)}",
                ),
                InfoLigne(
                  icon: Icons.autorenew_rounded,
                  texte: o.nbRenouvellements == 0
                      ? 'Non renouvelable'
                      : '${o.nbRenouvellements} renouvellement${o.nbRenouvellements > 1 ? 's' : ''}',
                ),
                if (origine != null)
                  InfoLigne(icon: Icons.content_copy_rounded, texte: 'Copie de $origine'),
              ],
            ),
            if (motif != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: 'Annulée : $motif'),
            ],
            if (hash != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    signatureValide ? Icons.lock_rounded : Icons.gpp_bad_rounded,
                    size: 18,
                    color: signatureValide ? AppColors.success : AppColors.danger,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      signatureValide
                          ? 'Signée et verrouillée · SHA-256 ${hash.substring(0, 12)}…'
                          : 'Ordonnance modifiée : signature invalide',
                      style: TextStyle(
                        fontSize: 13,
                        color: signatureValide ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Validité et renouvellements d'un brouillon.
class _Validite extends StatelessWidget {
  const _Validite({
    required this.ordonnance,
    required this.occupe,
    required this.onExpiration,
    required this.onRenouvellements,
  });

  final Ordonnance ordonnance;
  final bool occupe;
  final VoidCallback onExpiration;
  final ValueChanged<int> onRenouvellements;

  @override
  Widget build(BuildContext context) {
    final int nb = ordonnance.nbRenouvellements;

    return SectionFormulaire(
      titre: 'Validité',
      icon: Icons.event_available_outlined,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_month_outlined),
          title: const Text("Valable jusqu'au"),
          subtitle: Text(Formatters.date(ordonnance.dateExpiration)),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: occupe ? null : onExpiration,
        ),
        Row(
          children: [
            const Icon(Icons.autorenew_rounded, color: AppColors.textSecondary),
            const SizedBox(width: 16),
            const Expanded(child: Text('Renouvellements autorisés')),
            IconButton(
              tooltip: 'Moins',
              onPressed: occupe || nb <= 0 ? null : () => onRenouvellements(nb - 1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$nb', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            IconButton(
              tooltip: 'Plus',
              onPressed: occupe || nb >= ReglesOrdonnance.renouvellementsMax
                  ? null
                  : () => onRenouvellements(nb + 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }
}

/// Une ligne : médicament, posologie, boîtes, délivrance.
class _CarteLigne extends StatelessWidget {
  const _CarteLigne({
    required this.detail,
    required this.brouillon,
    this.onTap,
    this.onSupprimer,
  });

  final LigneDetail detail;
  final bool brouillon;
  final VoidCallback? onTap;
  final VoidCallback? onSupprimer;

  @override
  Widget build(BuildContext context) {
    final LigneOrdonnance l = detail.ligne;
    final String? instructions = l.instructions;
    final VoidCallback? supprimer = onSupprimer;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(StyleCategorie.iconeForme(detail.medicament.forme), color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.medicament.libelle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(detail.posologie, style: const TextStyle(color: AppColors.textPrimary)),
                    if (instructions != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          instructions,
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        BadgeStatut(
                          libelle: brouillon
                              ? Posologie.boites(l.quantiteBoites)
                              : 'Délivré ${l.quantiteDelivree}/${l.quantiteBoites}',
                          icon: Icons.inventory_2_outlined,
                          couleur: !brouillon && l.estDelivree ? AppColors.success : AppColors.primary,
                        ),
                        if (l.lienApci)
                          const BadgeStatut(
                            libelle: 'APCI 100 %',
                            icon: Icons.favorite_rounded,
                            couleur: AppColors.danger,
                          ),
                        if (!l.substitutionAutorisee)
                          const BadgeStatut(
                            libelle: 'Non substituable',
                            icon: Icons.block_rounded,
                            couleur: AppColors.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (supprimer != null)
                IconButton(
                  tooltip: 'Retirer',
                  onPressed: supprimer,
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
