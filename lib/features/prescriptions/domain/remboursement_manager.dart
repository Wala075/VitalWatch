import 'package:sqflite/sqflite.dart';

import '../../../core/utils/formatters.dart';
import '../data/api/konnect_api.dart';
import '../data/assurance_repository.dart';
import '../data/contrat_assurance_repository.dart';
import '../data/dossier_remboursement_repository.dart';
import '../data/prescriptions_schema.dart';
import '../data/taux_couverture_repository.dart';
import 'calcul_prise_en_charge.dart';
import 'models/assurance.dart';
import 'models/contrat_assurance.dart';
import 'models/dossier_remboursement.dart';
import 'models/medicament.dart';
import 'models/ordonnance.dart';
import 'models/vues_ordonnance.dart';
import 'models/vues_remboursement.dart';
import 'ordonnance_manager.dart';
import 'prescriptions_exception.dart';
import 'service_cnam_simule.dart';

/// Métiers 7 à 10 : éligibilité, calcul de prise en charge, workflow du
/// dossier de remboursement, plafond annuel, paiement du reste à charge.
class RemboursementManager {
  RemboursementManager({
    OrdonnanceManager? ordonnances,
    ContratAssuranceRepository? contrats,
    AssuranceRepository? assurances,
    TauxCouvertureRepository? taux,
    DossierRemboursementRepository? dossiers,
    KonnectApi? konnect,
  })  : _ordonnances = ordonnances ?? OrdonnanceManager(),
        _contrats = contrats ?? ContratAssuranceRepository(),
        _assurances = assurances ?? AssuranceRepository(),
        _taux = taux ?? TauxCouvertureRepository(),
        _dossiers = dossiers ?? DossierRemboursementRepository(),
        _konnect = konnect ?? KonnectApi();

  final OrdonnanceManager _ordonnances;
  final ContratAssuranceRepository _contrats;
  final AssuranceRepository _assurances;
  final TauxCouvertureRepository _taux;
  final DossierRemboursementRepository _dossiers;
  final KonnectApi _konnect;

  // =====================================================================
  // Contrats et plafond (métier 10)
  // =====================================================================

  Future<ContratDetail?> detailContrat(ContratAssurance c) async {
    final Assurance? a = await _assurances.parId(c.assuranceId);
    if (a == null) {
      return null;
    }
    return ContratDetail(
      contrat: c,
      assurance: a,
      consomme: await _dossiers.plafondConsomme(c.id!),
    );
  }

  /// Tous les contrats du patient avec la jauge de leur plafond.
  Future<List<ContratDetail>> contratsDuPatient(int patientId) async {
    final List<ContratDetail> res = [];
    for (final ContratAssurance c in await _contrats.parPatient(patientId)) {
      final ContratDetail? d = await detailContrat(c);
      if (d != null) {
        res.add(d);
      }
    }
    return res;
  }

  // =====================================================================
  // Éligibilité (métier 7)
  // =====================================================================

  /// Contrat CNAM actif à la date de l'ordonnance, plafond restant, mutuelle.
  Future<Eligibilite> eligibilite(Ordonnance o) async {
    final List<String> bloquants = [];
    final List<String> remarques = [];
    ContratDetail? cnam;
    ContratDetail? complementaire;

    for (final ContratAssurance c in await _contrats.actifsLe(o.patientId, o.dateEmission)) {
      final ContratDetail? d = await detailContrat(c);
      if (d == null) {
        continue;
      }
      if (d.assurance.estObligatoire) {
        cnam ??= d;
      } else {
        complementaire ??= d;
      }
    }

    double? plafondRestant;
    if (cnam == null) {
      bloquants.add(
        "Aucun contrat CNAM actif à la date de l'ordonnance (${Formatters.date(o.dateEmission)})",
      );
    } else {
      plafondRestant = cnam.restant;
      if (plafondRestant != null && plafondRestant <= 0) {
        remarques.add('Plafond annuel CNAM atteint : la CNAM ne rembourse plus cette année');
      } else if (cnam.alerte) {
        remarques.add('Attention : plus de 80 % du plafond annuel CNAM est déjà consommé');
      }
    }
    if (complementaire == null) {
      remarques.add('Pas de mutuelle active : le reste après la CNAM est à votre charge');
    }
    return Eligibilite(
      cnam: cnam,
      complementaire: complementaire,
      plafondRestant: plafondRestant,
      bloquants: bloquants,
      remarques: remarques,
    );
  }

  // =====================================================================
  // Calcul de prise en charge (métier 8)
  // =====================================================================

  /// [simulation] : avant l'achat, sur les boîtes prescrites (« combien je
  /// vais payer »). Sinon, sur les boîtes délivrées (dossier).
  Future<DetailPriseEnCharge> calculer(Ordonnance o, {bool simulation = false}) async {
    final Eligibilite e = await eligibilite(o);
    final List<String> remarques = [...e.bloquants, ...e.remarques];
    final bool enApci = await _ordonnances.estEnApci(o.patientId, o.dateEmission);
    double? plafond = e.plafondRestant;

    final List<DetailLigne> lignes = [];
    for (final LigneDetail d in await _ordonnances.lignesDetaillees(o.id!)) {
      final int boites = simulation ? d.ligne.quantiteBoites : d.ligne.quantiteDelivree;
      if (boites == 0) {
        continue;
      }
      final bool apci = d.ligne.lienApci && enApci;
      if (d.ligne.lienApci && !enApci) {
        remarques.add('${d.medicament.libelle} : APCI non reconnue, taux normal appliqué');
      }
      final DetailLigne ligne = await _calculerMedicament(
        d.medicament,
        boites,
        apci: apci,
        eligibilite: e,
        plafondRestant: plafond,
      );
      lignes.add(ligne);
      if (plafond != null) {
        plafond = plafond - ligne.partCnam;
      }
    }
    return DetailPriseEnCharge(lignes: lignes, remarques: remarques);
  }

  /// Prise en charge d'un médicament pour le patient aujourd'hui
  /// (économie d'une substitution générique).
  Future<DetailLigne> simulerMedicament(int patientId, Medicament m, int boites) async {
    final DateTime jour = DateTime.now();
    final Eligibilite e = await eligibilite(Ordonnance(
      numero: '',
      patientId: patientId,
      medecinId: 0,
      dateEmission: jour,
      dateExpiration: jour.add(const Duration(days: 1)),
    ));
    return _calculerMedicament(m, boites, apci: false, eligibilite: e, plafondRestant: e.plafondRestant);
  }

  Future<DetailLigne> _calculerMedicament(
    Medicament m,
    int boites, {
    required bool apci,
    required Eligibilite eligibilite,
    double? plafondRestant,
  }) async {
    final ContratDetail? cnam = eligibilite.cnam;
    final ContratDetail? complementaire = eligibilite.complementaire;
    final double tauxCnam =
        cnam == null ? 0 : (await _taux.taux(cnam.assurance.id!, m.categorie.valeur) ?? 0);
    final double? tauxMutuelle = complementaire == null
        ? null
        : await _taux.taux(complementaire.assurance.id!, m.categorie.valeur);
    return CalculPriseEnCharge.calculerLigne(
      libelle: m.libelle,
      prixPublic: m.prixPublic,
      prixReference: m.prixReference,
      boites: boites,
      tauxCnam: tauxCnam,
      apci: apci && cnam != null,
      tauxMutuelle: tauxMutuelle,
      plafondRestant: plafondRestant,
    );
  }

  // =====================================================================
  // Dossier de remboursement (métier 9)
  // =====================================================================

  Future<List<DossierResume>> dossiers({int? patientId, StatutDossier? statut}) {
    return _dossiers.listerResumes(patientId: patientId, statut: statut);
  }

  Future<DossierResume?> dossier(int id) async {
    // Charge les clés Konnect (mode démo ou réel) avant d'afficher le dossier.
    await KonnectConfig.charger();
    return _dossiers.resume(id);
  }

  /// Dossier en cours (non refusé) d'une ordonnance, s'il existe.
  Future<DossierRemboursement?> dossierDe(int ordonnanceId) async {
    for (final DossierRemboursement d in await _dossiers.parOrdonnance(ordonnanceId)) {
      if (d.statut != StatutDossier.refuse) {
        return d;
      }
    }
    return null;
  }

  /// Généré depuis une ordonnance délivrée (au moins en partie).
  Future<int> creerDossier(Ordonnance o) async {
    if (o.statut != StatutOrdonnance.delivree && o.statut != StatutOrdonnance.partiellementDelivree) {
      throw const PrescriptionsException('Le dossier se crée après la délivrance par le pharmacien');
    }
    final DossierRemboursement? existant = await dossierDe(o.id!);
    if (existant != null) {
      throw PrescriptionsException('Un dossier existe déjà pour cette ordonnance : ${existant.numero}');
    }
    final Eligibilite e = await eligibilite(o);
    if (!e.eligible) {
      throw PrescriptionsException(e.bloquants.join('\n'));
    }
    final DetailPriseEnCharge detail = await calculer(o);
    if (detail.lignes.isEmpty) {
      throw const PrescriptionsException('Aucune boîte délivrée sur cette ordonnance');
    }

    final Database db = await PrescriptionsSchema.database;
    return db.transaction((Transaction txn) async {
      return _dossiers.inserer(
        DossierRemboursement(
          numero: await _dossiers.prochainNumero(DateTime.now().year, exec: txn),
          ordonnanceId: o.id!,
          contratId: e.cnam!.contrat.id!,
          contratComplementaireId: e.complementaire?.contrat.id,
          montantTotal: detail.montant,
          partObligatoire: detail.partCnam,
          partComplementaire: detail.partMutuelle,
          resteACharge: detail.resteACharge,
        ),
        exec: txn,
      );
    });
  }

  /// Dépôt (brouillon → soumis) ou recours (refusé → soumis, motif conservé).
  Future<void> soumettre(DossierRemboursement d) async {
    if (d.statut != StatutDossier.brouillon && d.statut != StatutDossier.refuse) {
      throw const PrescriptionsException('Ce dossier a déjà été soumis');
    }
    await _dossiers.modifier(_copie(d, statut: StatutDossier.soumis, dateDepot: DateTime.now()));
  }

  /// La CNAM simulée prend le dossier (soumis → en cours).
  Future<void> prendreEnCharge(DossierRemboursement d) async {
    if (d.statut != StatutDossier.soumis) {
      return;
    }
    await _dossiers.modifier(_copie(d, statut: StatutDossier.enCours));
  }

  /// Réponse du service CNAM simulé (règles fixes, ou issue forcée en démo).
  Future<ReponseCnam> traiterParCnam(
    DossierRemboursement d, {
    IssueCnam issue = IssueCnam.automatique,
    String? motif,
  }) async {
    if (d.statut != StatutDossier.soumis && d.statut != StatutDossier.enCours) {
      throw const PrescriptionsException('Seul un dossier soumis ou en cours reçoit une réponse');
    }
    final DossierResume? resume = await _dossiers.resume(d.id!);
    final ContratAssurance? contrat = await _contrats.parId(d.contratId);
    final bool actif = contrat != null && resume != null && contrat.estActifLe(resume.dateOrdonnance);
    final ContratDetail? detail = contrat == null ? null : await detailContrat(contrat);

    final ReponseCnam reponse = ServiceCnamSimule.repondre(
      dossier: d,
      contratActif: actif,
      plafondRestant: detail?.restant,
      issue: issue,
      motif: motif,
    );
    await _dossiers.modifier(DossierRemboursement(
      id: d.id,
      numero: d.numero,
      ordonnanceId: d.ordonnanceId,
      contratId: d.contratId,
      contratComplementaireId: d.contratComplementaireId,
      montantTotal: d.montantTotal,
      partObligatoire: reponse.partObligatoire,
      partComplementaire: d.partComplementaire,
      resteACharge: reponse.resteACharge,
      statut: reponse.statut,
      dateDepot: d.dateDepot,
      dateReponse: DateTime.now(),
      motifRefus: reponse.motifRefus ?? d.motifRefus,
      restePaye: d.restePaye,
      referencePaiement: d.referencePaiement,
    ));
    return reponse;
  }

  /// Virement de la CNAM reçu (accepté ou partiel → remboursé).
  Future<void> marquerRembourse(DossierRemboursement d) async {
    if (d.statut != StatutDossier.accepte && d.statut != StatutDossier.partiel) {
      throw const PrescriptionsException('Seul un dossier accepté ou partiel peut être remboursé');
    }
    await _dossiers.modifier(_copie(d, statut: StatutDossier.rembourse));
  }

  Future<void> supprimerBrouillon(DossierRemboursement d) async {
    if (d.statut != StatutDossier.brouillon) {
      throw const PrescriptionsException('Seul un dossier en brouillon peut être supprimé');
    }
    await _dossiers.supprimer(d.id!);
  }

  DossierRemboursement _copie(
    DossierRemboursement d, {
    StatutDossier? statut,
    DateTime? dateDepot,
    bool? restePaye,
    String? referencePaiement,
  }) {
    return DossierRemboursement(
      id: d.id,
      numero: d.numero,
      ordonnanceId: d.ordonnanceId,
      contratId: d.contratId,
      contratComplementaireId: d.contratComplementaireId,
      montantTotal: d.montantTotal,
      partObligatoire: d.partObligatoire,
      partComplementaire: d.partComplementaire,
      resteACharge: d.resteACharge,
      statut: statut ?? d.statut,
      dateDepot: dateDepot ?? d.dateDepot,
      dateReponse: d.dateReponse,
      motifRefus: d.motifRefus,
      restePaye: restePaye ?? d.restePaye,
      referencePaiement: referencePaiement ?? d.referencePaiement,
    );
  }

  // =====================================================================
  // Paiement du reste à charge (Konnect)
  // =====================================================================

  static bool peutPayer(DossierRemboursement d) {
    final bool repondu = d.statut == StatutDossier.accepte ||
        d.statut == StatutDossier.partiel ||
        d.statut == StatutDossier.rembourse;
    return repondu && !d.restePaye && d.resteACharge > 0;
  }

  bool get paiementEnDemo => !KonnectConfig.estConfigure;

  /// Crée le paiement. Renvoie l'adresse de la page Konnect à ouvrir, ou null
  /// en mode démonstration (pas de clé : le paiement est simulé et réglé).
  Future<String?> payer(DossierResume r) async {
    final DossierRemboursement d = r.dossier;
    if (!peutPayer(d)) {
      throw const PrescriptionsException('Rien à payer sur ce dossier');
    }
    await KonnectConfig.charger();
    final Database db = await PrescriptionsSchema.database;
    final List<Map<String, Object?>> patients = await db.query(
      'patients',
      columns: ['prenom', 'nom', 'email', 'telephone'],
      where: 'id = ?',
      whereArgs: [r.patientId],
      limit: 1,
    );
    final Map<String, Object?> patient = patients.isEmpty ? const {} : patients.first;
    if (!KonnectConfig.estConfigure) {
      await _dossiers.modifier(_copie(
        d,
        restePaye: true,
        referencePaiement: 'DEMO-${d.numero}-${DateTime.now().millisecondsSinceEpoch}',
      ));
      return null;
    }
    final PaiementInitie p = await _konnect.initier(
      montantMillimes: (d.resteACharge * 1000).round(),
      reference: d.numero,
      description: 'VitalWatch ${d.numero} · ordonnance ${r.ordonnanceNumero}',
      prenom: patient['prenom'] as String?,
      nom: patient['nom'] as String?,
      email: patient['email'] as String?,
      telephone: patient['telephone'] as String?,
    );
    await _dossiers.modifier(_copie(d, referencePaiement: p.paymentRef));
    return p.payUrl;
  }

  /// Vérifie chez Konnect que le paiement est terminé et le marque payé.
  Future<bool> verifierPaiement(DossierRemboursement d) async {
    final String? ref = d.referencePaiement;
    if (d.restePaye) {
      return true;
    }
    if (ref == null) {
      return false;
    }
    final bool paye = await _konnect.estPaye(ref);
    if (paye) {
      await _dossiers.modifier(_copie(d, restePaye: true));
    }
    return paye;
  }
}
