import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/formats_prescriptions.dart';
import '../../domain/models/dossier_remboursement.dart';
import '../../domain/models/vues_remboursement.dart';
import '../../domain/prescriptions_exception.dart';
import '../../domain/remboursement_manager.dart';
import '../../domain/service_cnam_simule.dart';
import '../widgets/elements_ui.dart';

/// Fiche d'un dossier de remboursement.
/// Patient : soumettre, recours, payer le reste. Admin : réponse de la CNAM
/// simulée, relance, remboursement.
class DossierDetailScreen extends StatefulWidget {
  const DossierDetailScreen({super.key, required this.dossierId, required this.admin});

  final int dossierId;

  /// true pour l'admin (traitement), false pour le patient.
  final bool admin;

  @override
  State<DossierDetailScreen> createState() => _DossierDetailScreenState();
}

class _DossierDetailScreenState extends State<DossierDetailScreen> {
  final RemboursementManager _manager = RemboursementManager();

  DossierResume? _resume;
  bool _occupe = false;
  String? _attente;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final DossierResume? r = await _manager.dossier(widget.dossierId);
    if (!mounted) {
      return;
    }
    setState(() => _resume = r);
  }

  Future<void> _executer(Future<void> Function() action, {String? attente}) async {
    setState(() {
      _occupe = true;
      _attente = attente;
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
        setState(() {
          _occupe = false;
          _attente = null;
        });
      }
    }
    await _charger();
  }

  /// Choix de la réponse de la CNAM simulée (automatique ou forcée en démo).
  Future<_Choix?> _choisirIssue() {
    return showModalBottomSheet<_Choix>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _ChoixIssue(),
    );
  }

  /// Dépôt (ou recours), prise en charge, puis réponse après un court délai.
  Future<void> _soumettre(DossierRemboursement d) async {
    final _Choix? choix = await _choisirIssue();
    if (choix == null) {
      return;
    }
    await _executer(
      () async {
        await _manager.soumettre(d);
        DossierResume? r = await _manager.dossier(d.id!);
        if (r != null) {
          await _manager.prendreEnCharge(r.dossier);
        }
        if (mounted) {
          setState(() => _attente = 'La CNAM étudie votre dossier…');
        }
        await Future<void>.delayed(ServiceCnamSimule.delai);
        r = await _manager.dossier(d.id!);
        if (r != null) {
          await _manager.traiterParCnam(r.dossier, issue: choix.issue, motif: choix.motif);
        }
      },
      attente: 'Envoi à la CNAM…',
    );
  }

  Future<void> _repondre(DossierRemboursement d) async {
    final _Choix? choix = await _choisirIssue();
    if (choix == null) {
      return;
    }
    await _executer(() async {
      await _manager.traiterParCnam(d, issue: choix.issue, motif: choix.motif);
    });
  }

  Future<void> _payer(DossierResume r) async {
    String? url;
    await _executer(() async {
      url = await _manager.payer(r);
    }, attente: 'Création du paiement Konnect…');
    final String? lien = url;
    if (!mounted || _erreur != null) {
      return;
    }
    if (lien == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paiement simulé (mode démo, sans clé Konnect) : réglé')),
      );
      return;
    }
    final bool ouvert = await launchUrl(Uri.parse(lien), mode: LaunchMode.externalApplication);
    if (!ouvert && mounted) {
      setState(() => _erreur = 'Impossible d’ouvrir la page de paiement');
    }
  }

  Future<void> _verifier(DossierRemboursement d) async {
    bool paye = false;
    await _executer(() async {
      paye = await _manager.verifierPaiement(d);
    }, attente: 'Vérification chez Konnect…');
    if (!mounted || _erreur != null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(paye ? 'Paiement confirmé' : 'Paiement pas encore terminé')),
    );
  }

  Future<void> _supprimer(DossierRemboursement d) async {
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Supprimer ${d.numero} ?',
      message: 'Le brouillon de dossier sera supprimé.',
      confirmer: 'Supprimer',
      danger: true,
    );
    if (!ok) {
      return;
    }
    try {
      await _manager.supprimerBrouillon(d);
      if (mounted) {
        Navigator.pop(context);
      }
    } on PrescriptionsException catch (e) {
      if (mounted) {
        setState(() => _erreur = e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DossierResume? r = _resume;
    if (r == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final DossierRemboursement d = r.dossier;
    final String? motif = d.motifRefus;
    final DateTime? depot = d.dateDepot;
    final DateTime? reponse = d.dateReponse;
    final String? attente = _attente;

    return Scaffold(
      appBar: AppBar(
        title: Text(d.numero),
        actions: [
          if (!widget.admin && d.statut == StatutDossier.brouillon)
            IconButton(
              tooltip: 'Supprimer',
              onPressed: _occupe ? null : () => _supprimer(d),
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
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
                            r.patientNom,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        ),
                        StyleDossier.badge(d.statut),
                      ],
                    ),
                    Text(
                      'Ordonnance ${r.ordonnanceNumero} du ${Formatters.date(r.dateOrdonnance)} · ${r.assuranceNom}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        if (depot != null)
                          InfoLigne(icon: Icons.outbox_outlined, texte: 'Déposé le ${Formatters.date(depot)}'),
                        if (reponse != null)
                          InfoLigne(icon: Icons.mark_email_read_outlined, texte: 'Réponse le ${Formatters.date(reponse)}'),
                        InfoLigne(icon: Icons.schedule_rounded, texte: 'Délai CNAM : ${r.delaiReponseJours} j'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (r.enRetard) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Sans réponse depuis plus de ${r.delaiReponseJours} jours : relance automatique.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (motif != null) ...[
              ErrorBanner(
                message: d.statut == StatutDossier.refuse
                    ? 'Refusé : $motif'
                    : 'Motif du refus précédent : $motif',
              ),
              const SizedBox(height: 12),
            ],
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _Montant('Montant total', d.montantTotal),
                    _Montant('Part CNAM (obligatoire)', d.partObligatoire),
                    _Montant('Part mutuelle (complémentaire)', d.partComplementaire),
                    const Divider(),
                    _Montant('Reste à charge', d.resteACharge, gras: true),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          d.restePaye ? Icons.check_circle_rounded : Icons.payments_outlined,
                          color: d.restePaye ? AppColors.success : AppColors.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            d.restePaye
                                ? 'Reste payé${d.referencePaiement == null ? '' : ' · ${d.referencePaiement}'}'
                                : d.referencePaiement == null
                                    ? 'Reste non payé'
                                    : 'Paiement en cours · ${d.referencePaiement}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (attente != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    const SizedBox(width: 10),
                    Text(attente),
                  ],
                ),
              ),
            if (_erreur != null) ...[
              ErrorBanner(message: _erreur!),
              const SizedBox(height: 12),
            ],
            ..._actions(r),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(DossierResume r) {
    final DossierRemboursement d = r.dossier;
    final List<Widget> res = [];
    void ajouter(Widget w) {
      res.add(w);
      res.add(const SizedBox(height: 10));
    }

    if (!widget.admin) {
      if (d.statut == StatutDossier.brouillon) {
        ajouter(PrimaryButton(
          label: 'Soumettre à la CNAM',
          icon: Icons.send_rounded,
          loading: _occupe,
          onPressed: () => _soumettre(d),
        ));
      }
      if (d.statut == StatutDossier.refuse) {
        ajouter(PrimaryButton(
          label: 'Faire un recours',
          icon: Icons.replay_rounded,
          loading: _occupe,
          onPressed: () => _soumettre(d),
        ));
      }
      if (RemboursementManager.peutPayer(d) && d.referencePaiement == null) {
        ajouter(PrimaryButton(
          label: 'Payer ${FormatsPrescriptions.dt(d.resteACharge)} avec Konnect',
          icon: Icons.credit_card_rounded,
          loading: _occupe,
          onPressed: () => _payer(r),
        ));
        if (_manager.paiementEnDemo) {
          ajouter(const Text(
            'Mode démo : aucune clé Konnect configurée, le paiement est simulé.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ));
        }
      }
      if (!d.restePaye && d.referencePaiement != null) {
        ajouter(SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _occupe ? null : () => _verifier(d),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Vérifier le paiement'),
          ),
        ));
      }
    } else {
      if (d.statut == StatutDossier.soumis || d.statut == StatutDossier.enCours) {
        ajouter(PrimaryButton(
          label: r.enRetard ? 'Relancer la CNAM' : 'Réponse de la CNAM',
          icon: r.enRetard ? Icons.notification_important_rounded : Icons.gavel_rounded,
          loading: _occupe,
          onPressed: () => _repondre(d),
        ));
      }
      if (d.statut == StatutDossier.accepte || d.statut == StatutDossier.partiel) {
        ajouter(PrimaryButton(
          label: 'Marquer remboursé',
          icon: Icons.account_balance_wallet_rounded,
          loading: _occupe,
          onPressed: () => _executer(() => _manager.marquerRembourse(d)),
        ));
      }
    }
    return res;
  }
}

class _Montant extends StatelessWidget {
  const _Montant(this.libelle, this.valeur, {this.gras = false});

  final String libelle;
  final double valeur;
  final bool gras;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: gras ? 17 : 14,
      fontWeight: gras ? FontWeight.w800 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(libelle, style: style)),
          Text(FormatsPrescriptions.dt(valeur), style: style),
        ],
      ),
    );
  }
}

/// Issue choisie et motif éventuel du refus.
class _Choix {
  const _Choix(this.issue, this.motif);

  final IssueCnam issue;
  final String? motif;
}

class _ChoixIssue extends StatefulWidget {
  const _ChoixIssue();

  @override
  State<_ChoixIssue> createState() => _ChoixIssueState();
}

class _ChoixIssueState extends State<_ChoixIssue> {
  final TextEditingController _motifCtrl = TextEditingController();
  IssueCnam _issue = IssueCnam.automatique;

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Réponse de la CNAM (simulée)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Automatique : contrat expiré → refusé ; part supérieure au plafond '
              'restant → partiel ; sinon accepté. Les autres choix forcent l’issue '
              'pour la démonstration.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            for (final IssueCnam i in IssueCnam.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  i == _issue ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: AppColors.primary,
                ),
                title: Text(i.libelle),
                onTap: () => setState(() => _issue = i),
              ),
            if (_issue == IssueCnam.refuser)
              TextField(
                controller: _motifCtrl,
                decoration: InputDecoration(
                  labelText: 'Motif du refus',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _Choix(_issue, _motifCtrl.text.trim().isEmpty ? null : _motifCtrl.text.trim()),
              ),
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }
}
