import 'package:sqflite/sqflite.dart';

import '../data/contrat_assurance_repository.dart';
import '../data/ligne_ordonnance_repository.dart';
import '../data/medicament_repository.dart';
import '../data/ordonnance_repository.dart';
import '../data/prescriptions_schema.dart';
import '../data/prise_repository.dart';
import 'authenticite_ordonnance.dart';
import 'calcul_boites.dart';
import 'dates_sql.dart';
import 'models/contrat_assurance.dart';
import 'models/ligne_ordonnance.dart';
import 'models/medicament.dart';
import 'models/ordonnance.dart';
import 'models/prise.dart';
import 'models/vues_ordonnance.dart';
import 'planning_prises.dart';
import 'prescriptions_exception.dart';
import 'regles_ordonnance.dart';
import 'service_patients.dart';

/// Métier 1 : cycle de vie et verrouillage de l'ordonnance.
///
/// brouillon → validée → partiellement délivrée → délivrée ;
/// une ordonnance validée peut aussi devenir expirée ou annulée.
/// Après validation, rien ne se modifie : on annule, puis on corrige
/// (copie en brouillon) ou on renouvelle (copie validée).
class OrdonnanceManager {
  OrdonnanceManager({
    OrdonnanceRepository? ordonnances,
    LigneOrdonnanceRepository? lignes,
    MedicamentRepository? medicaments,
    PriseRepository? prises,
    ContratAssuranceRepository? contrats,
    ServicePatients? patients,
  })  : _ordonnances = ordonnances ?? OrdonnanceRepository(),
        _lignes = lignes ?? LigneOrdonnanceRepository(),
        _medicaments = medicaments ?? MedicamentRepository(),
        _prises = prises ?? PriseRepository(),
        _contrats = contrats ?? ContratAssuranceRepository(),
        _patients = patients ?? ServicePatients.instance;

  final OrdonnanceRepository _ordonnances;
  final LigneOrdonnanceRepository _lignes;
  final MedicamentRepository _medicaments;
  final PriseRepository _prises;
  final ContratAssuranceRepository _contrats;
  final ServicePatients _patients;

  Future<Database> get _db => PrescriptionsSchema.database;

  // =====================================================================
  // Lecture
  // =====================================================================

  Future<List<LigneDetail>> lignesDetaillees(int ordonnanceId) async {
    final List<LigneOrdonnance> lignes = await _lignes.parOrdonnance(ordonnanceId);
    final List<int> ids = [];
    for (final LigneOrdonnance l in lignes) {
      ids.add(l.medicamentId);
    }
    final Map<int, Medicament> medicaments = await _medicaments.parIds(ids);

    final List<LigneDetail> res = [];
    for (final LigneOrdonnance l in lignes) {
      final Medicament? m = medicaments[l.medicamentId];
      if (m != null) {
        res.add(LigneDetail(ligne: l, medicament: m));
      }
    }
    return res;
  }

  /// Le patient a-t-il un contrat APCI actif pour une de ses maladies chroniques ?
  Future<bool> estEnApci(int patientId, DateTime date) async {
    final List<String> chroniques = await _patients.codesCimChroniques(patientId);
    for (final ContratAssurance c in await _contrats.actifsLe(patientId, date)) {
      if (c.apci && chroniques.contains(c.codeApci)) {
        return true;
      }
    }
    return false;
  }

  // =====================================================================
  // Brouillon
  // =====================================================================

  /// Nouvelle ordonnance du jour, valable [Ordonnance.validiteJoursParDefaut] jours.
  Future<int> creerBrouillon({
    required int patientId,
    required int medecinId,
    int? consultationId,
  }) async {
    final DateTime jour = DatesSql.jour(DateTime.now());
    final Database db = await _db;
    return db.transaction((Transaction txn) async {
      return _ordonnances.inserer(
        Ordonnance(
          numero: await _ordonnances.prochainNumero(jour.year, exec: txn),
          patientId: patientId,
          medecinId: medecinId,
          consultationId: consultationId,
          dateEmission: jour,
          dateExpiration: jour.add(const Duration(days: Ordonnance.validiteJoursParDefaut)),
        ),
        exec: txn,
      );
    });
  }

  /// Date d'expiration et nombre de renouvellements (brouillon).
  Future<void> modifierEnTete(Ordonnance o) async {
    _exigerBrouillon(o);
    final String? erreur = ReglesOrdonnance.dates(o.dateEmission, o.dateExpiration) ??
        ReglesOrdonnance.renouvellements(o.nbRenouvellements);
    if (erreur != null) {
      throw PrescriptionsException(erreur);
    }
    await _ordonnances.modifier(o);
  }

  Future<void> supprimerBrouillon(Ordonnance o) async {
    _exigerBrouillon(o);
    await _ordonnances.supprimer(o.id!);
  }

  /// Ajoute ([ligneId] null) ou modifie une ligne ; les boîtes sont calculées.
  Future<void> enregistrerLigne({
    required Ordonnance ordonnance,
    int? ligneId,
    required Medicament medicament,
    required double dosePrise,
    required List<String> moments,
    required int dureeJours,
    bool substitutionAutorisee = true,
    bool lienApci = false,
    String? instructions,
  }) async {
    _exigerBrouillon(ordonnance);
    if (!medicament.actif) {
      throw const PrescriptionsException('Ce médicament est archivé : il ne peut plus être prescrit');
    }
    final List<String> tri = PlanningPrises.trier(moments);
    final String? erreur = ReglesOrdonnance.ligne(
      medicament: medicament,
      dosePrise: dosePrise,
      moments: tri,
      dureeJours: dureeJours,
    );
    if (erreur != null) {
      throw PrescriptionsException(erreur);
    }
    final int ordonnanceId = ordonnance.id!;
    if (await _lignes.dciPresente(ordonnanceId, medicament.dci, exclureLigneId: ligneId)) {
      throw const PrescriptionsException("Cette DCI figure déjà dans l'ordonnance");
    }
    if (lienApci && !await estEnApci(ordonnance.patientId, ordonnance.dateEmission)) {
      throw const PrescriptionsException("Ce patient n'est pas en APCI");
    }

    final String texte = (instructions ?? '').trim();
    final LigneOrdonnance l = LigneOrdonnance(
      id: ligneId,
      ordonnanceId: ordonnanceId,
      medicamentId: medicament.id!,
      dosePrise: dosePrise,
      prisesParJour: tri.length,
      moments: tri,
      dureeJours: dureeJours,
      quantiteBoites: CalculBoites.calculer(
        dosePrise: dosePrise,
        prisesParJour: tri.length,
        dureeJours: dureeJours,
        unitesParBoite: medicament.unitesParBoite,
      ),
      substitutionAutorisee: substitutionAutorisee,
      lienApci: lienApci,
      instructions: texte.isEmpty ? null : texte,
    );
    if (ligneId == null) {
      await _lignes.inserer(l);
    } else {
      await _lignes.modifier(l);
    }
  }

  Future<void> supprimerLigne(Ordonnance o, int ligneId) async {
    _exigerBrouillon(o);
    await _lignes.supprimer(ligneId);
  }

  // =====================================================================
  // Validation
  // =====================================================================

  /// Contrôles avant validation. Bloquants : dates, aucune ligne, médicament
  /// archivé, résultat bloquant de la gestion Patients. Avertissements :
  /// alerte de la gestion Patients, même DCI déjà en cours (chevauchement).
  Future<ControleValidation> controlerValidation(Ordonnance o) async {
    final List<String> bloquants = [];
    final List<String> avertissements = [];

    final String? dates = ReglesOrdonnance.dates(o.dateEmission, o.dateExpiration);
    if (dates != null) {
      bloquants.add(dates);
    }
    final List<LigneDetail> lignes = await lignesDetaillees(o.id!);
    if (lignes.isEmpty) {
      bloquants.add('Ajoutez au moins un médicament');
    }
    final List<TraitementActif> enCours =
        await _ordonnances.traitementsActifs(o.patientId, exclureOrdonnanceId: o.id);

    for (final LigneDetail d in lignes) {
      final Medicament m = d.medicament;
      if (!m.actif) {
        bloquants.add('${m.libelle} est archivé : retirez-le de l’ordonnance');
      }

      // Métier de la gestion Patients : allergies et interactions avec les
      // autres lignes et les traitements en cours.
      final List<String> autres = [];
      for (final LigneDetail autre in lignes) {
        if (autre.ligne.id != d.ligne.id) {
          autres.add(autre.medicament.dci);
        }
      }
      for (final TraitementActif t in enCours) {
        autres.add(t.dci);
      }
      final AnalyseTraitement analyse =
          await _patients.analyserTraitement(o.patientId, m.dci, autres);
      if (analyse.niveau == NiveauAnalyse.bloquant) {
        bloquants.add('${m.libelle} : ${analyse.message ?? 'contre-indiqué pour ce patient'}');
      } else if (analyse.niveau == NiveauAnalyse.attention) {
        avertissements.add('${m.libelle} : ${analyse.message ?? 'à surveiller'}');
      }

      // Métier 5 : chevauchement avec une ordonnance en cours.
      for (final TraitementActif t in enCours) {
        if (t.dci.toLowerCase() == m.dci.toLowerCase()) {
          if (t.medecinId == o.medecinId) {
            avertissements.add('${m.dci} figure déjà dans votre ordonnance ${t.numero} en cours');
          } else {
            avertissements.add('${m.dci} est déjà prescrit par ${t.medecinNom} (${t.numero})');
          }
        }
      }
    }
    return ControleValidation(bloquants: bloquants, avertissements: avertissements);
  }

  /// Valide le brouillon : contrôles, signature SHA-256, planning des prises.
  /// Renvoie le nombre de prises planifiées.
  Future<int> valider(Ordonnance o) async {
    _exigerBrouillon(o);
    final ControleValidation controle = await controlerValidation(o);
    if (!controle.peutValider) {
      throw PrescriptionsException(controle.bloquants.join('\n'));
    }
    final Database db = await _db;
    return db.transaction((Transaction txn) => _validerDans(txn, o.id!));
  }

  Future<int> _validerDans(Transaction txn, int ordonnanceId) async {
    // Relue dans la transaction : la signature porte sur l'état en base.
    final Ordonnance? o = await _ordonnances.parId(ordonnanceId, exec: txn);
    if (o == null) {
      throw const PrescriptionsException('Ordonnance introuvable');
    }
    final List<LigneOrdonnance> lignes = await _lignes.parOrdonnance(ordonnanceId, exec: txn);
    await _ordonnances.valider(ordonnanceId, AuthenticiteOrdonnance.signer(o, lignes), exec: txn);

    final DateTime debut = DateTime.now();
    final List<Prise> prises = [];
    for (final LigneOrdonnance l in lignes) {
      prises.addAll(PlanningPrises.generer(
        ligneId: l.id!,
        momentsLigne: l.moments,
        dureeJours: l.dureeJours,
        debut: debut,
      ));
    }
    await _prises.insererToutes(prises, exec: txn);
    return prises.length;
  }

  // =====================================================================
  // Après validation
  // =====================================================================

  static bool estAnnulable(StatutOrdonnance s) =>
      s == StatutOrdonnance.validee || s == StatutOrdonnance.partiellementDelivree;

  static bool estRenouvelable(Ordonnance o) =>
      o.nbRenouvellements > 0 &&
      (o.statut == StatutOrdonnance.partiellementDelivree ||
          o.statut == StatutOrdonnance.delivree ||
          o.statut == StatutOrdonnance.expiree);

  Future<void> annuler(Ordonnance o, String motif) async {
    _exigerAnnulable(o, motif);
    await _ordonnances.annuler(o.id!, motif);
  }

  /// Correction : annulation avec motif, puis copie en brouillon reliée par
  /// ordonnance_origine_id. Renvoie l'id du nouveau brouillon.
  Future<int> corriger(Ordonnance o, String motif) async {
    _exigerAnnulable(o, motif);
    final Database db = await _db;
    return db.transaction((Transaction txn) async {
      await _ordonnances.annuler(o.id!, motif, exec: txn);
      return _copier(txn, o, nbRenouvellements: o.nbRenouvellements);
    });
  }

  /// Renouvellement : copie validée émise aujourd'hui, reliée à l'originale.
  /// Le compteur décrémenté passe sur la copie (l'originale tombe à 0), pour
  /// qu'une même ordonnance ne soit jamais renouvelée deux fois.
  /// Renvoie l'id de la copie.
  Future<int> renouveler(Ordonnance o) async {
    if (!estRenouvelable(o)) {
      throw const PrescriptionsException(
        'Renouvellement impossible : plus aucun renouvellement ou ordonnance pas encore délivrée',
      );
    }
    // Les allergies du patient ont pu changer depuis : mêmes contrôles.
    final ControleValidation controle = await controlerValidation(o);
    if (!controle.peutValider) {
      throw PrescriptionsException(controle.bloquants.join('\n'));
    }
    final Database db = await _db;
    return db.transaction((Transaction txn) async {
      final int copie = await _copier(txn, o, nbRenouvellements: o.nbRenouvellements - 1);
      await _validerDans(txn, copie);
      await _ordonnances.changerRenouvellements(o.id!, 0, exec: txn);
      return copie;
    });
  }

  /// Copie en brouillon (nouveau numéro, émise aujourd'hui) avec ses lignes.
  Future<int> _copier(Transaction txn, Ordonnance o, {required int nbRenouvellements}) async {
    final DateTime jour = DatesSql.jour(DateTime.now());
    final int copieId = await _ordonnances.inserer(
      Ordonnance(
        numero: await _ordonnances.prochainNumero(jour.year, exec: txn),
        patientId: o.patientId,
        medecinId: o.medecinId,
        consultationId: o.consultationId,
        dateEmission: jour,
        dateExpiration: jour.add(const Duration(days: Ordonnance.validiteJoursParDefaut)),
        nbRenouvellements: nbRenouvellements,
        ordonnanceOrigineId: o.id,
      ),
      exec: txn,
    );
    for (final LigneOrdonnance l in await _lignes.parOrdonnance(o.id!, exec: txn)) {
      await _lignes.inserer(
        LigneOrdonnance(
          ordonnanceId: copieId,
          medicamentId: l.medicamentId,
          dosePrise: l.dosePrise,
          prisesParJour: l.prisesParJour,
          moments: l.moments,
          dureeJours: l.dureeJours,
          quantiteBoites: l.quantiteBoites,
          substitutionAutorisee: l.substitutionAutorisee,
          lienApci: l.lienApci,
          instructions: l.instructions,
        ),
        exec: txn,
      );
    }
    return copieId;
  }

  void _exigerBrouillon(Ordonnance o) {
    if (!o.estModifiable) {
      throw const PrescriptionsException(
        'Ordonnance validée : elle ne se modifie plus, elle s’annule',
      );
    }
  }

  void _exigerAnnulable(Ordonnance o, String motif) {
    if (!estAnnulable(o.statut)) {
      throw PrescriptionsException(
        'Une ordonnance « ${o.statut.libelle.toLowerCase()} » ne peut pas être annulée',
      );
    }
    final String? erreur = ReglesOrdonnance.motifAnnulation(motif);
    if (erreur != null) {
      throw PrescriptionsException(erreur);
    }
  }
}
