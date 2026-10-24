import '../../../models/infirmier.dart';
import '../../../models/medecin.dart';
import '../../../models/patient.dart';
import '../../../models/utilisateur.dart';
import '../data/conge_repository.dart';
import '../data/infirmier_repository.dart';
import '../data/medecin_repository.dart';
import '../data/patient_repository.dart';
import 'conges.dart';
import 'staff_models.dart';

/// Métier « Demandes de congé » : un médecin ou un infirmier demande,
/// l'admin valide ou refuse.
///
/// Règles :
/// - dates cohérentes (pas dans le passé, fin ≥ début, 90 jours max) ;
/// - pas de chevauchement avec une autre demande de la même personne ;
/// - congé annuel : 30 jours par année civile au maximum ;
/// - effectif minimum : il doit rester au moins un collègue du même rôle
///   présent dans le service chaque jour, sinon refus automatique
///   (à la demande ET à la validation, la situation ayant pu changer) ;
/// - médecin absent 7 jours ou plus : ses patients sont confiés au collègue
///   le moins chargé du service, présent sur la période.
class CongeManager {
  final CongeRepository _conges = CongeRepository();
  final MedecinRepository _medecins = MedecinRepository();
  final InfirmierRepository _infirmiers = InfirmierRepository();
  final PatientRepository _patients = PatientRepository();

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Demande d'un médecin ou d'un infirmier pour lui-même.
  Future<int> demander(Conge c, {DateTime? aujourdHui}) async {
    final String? erreurDates = RegleConges.verifierDates(
      c.debut,
      c.fin,
      aujourdHui ?? DateTime.now(),
    );
    if (erreurDates != null) {
      throw StaffException(erreurDates);
    }
    if (c.type == TypeConge.exceptionnel && c.motif.trim().isEmpty) {
      throw const StaffException('Précisez le motif du congé exceptionnel');
    }

    final List<Conge> miens = await _conges.dePersonne(
      c.role,
      c.demandeurId,
      statuts: const [StatutConge.enAttente, StatutConge.validee],
    );
    for (final Conge m in miens) {
      if (RegleConges.chevauchent(c.debut, c.fin, m.debut, m.fin)) {
        throw StaffException(
          'Vous avez déjà une demande du ${_date(m.debut)} au ${_date(m.fin)} '
          'sur cette période',
        );
      }
    }

    if (c.type == TypeConge.annuel) {
      final String? erreurSolde =
          RegleConges.verifierSolde(c.debut, c.fin, _joursAnnuels(miens));
      if (erreurSolde != null) {
        throw StaffException(erreurSolde);
      }
    }

    final String? sousEffectif = await _verifierEffectif(c);
    if (sousEffectif != null) {
      throw StaffException(sousEffectif);
    }

    return _conges.inserer(Conge(
      role: c.role,
      demandeurId: c.demandeurId,
      debut: c.debut,
      fin: c.fin,
      type: c.type,
      motif: c.motif.trim(),
    ));
  }

  /// Jours de congé annuel (validés ou en attente) par année.
  Map<int, int> _joursAnnuels(List<Conge> conges) {
    final Map<int, int> res = {};
    for (final Conge m in conges) {
      if (m.type != TypeConge.annuel) continue;
      RegleConges.joursParAnnee(m.debut, m.fin).forEach((int annee, int n) {
        res[annee] = (res[annee] ?? 0) + n;
      });
    }
    return res;
  }

  /// Jours de congé annuel restants cette année (affichage).
  Future<int> soldeRestant(Role role, int id) async {
    final List<Conge> miens = await _conges.dePersonne(
      role,
      id,
      statuts: const [StatutConge.enAttente, StatutConge.validee],
    );
    final int pris = _joursAnnuels(miens)[DateTime.now().year] ?? 0;
    final int reste = RegleConges.soldeAnnuel - pris;
    return reste < 0 ? 0 : reste;
  }

  /// Message de refus si le service passerait sous l'effectif minimum.
  Future<String?> _verifierEffectif(Conge c) async {
    int? serviceId;
    final List<Collegue> collegues = [];

    if (c.role == Role.medecin) {
      final Medecin? moi = await _medecins.parId(c.demandeurId);
      serviceId = moi?.serviceId;
      if (serviceId == null) return null;
      final List<MedecinDetail> equipe =
          await _medecins.rechercher(MedecinFiltre(serviceId: serviceId));
      for (final MedecinDetail d in equipe) {
        final int? id = d.medecin.id;
        if (id == null || id == c.demandeurId) continue;
        collegues.add(await _collegue(Role.medecin, id, d.medecin.disponible));
      }
    } else {
      final Infirmier? moi = await _infirmiers.parId(c.demandeurId);
      serviceId = moi?.serviceId;
      if (serviceId == null) return null;
      final List<InfirmierDetail> equipe = await _infirmiers.rechercher();
      for (final InfirmierDetail d in equipe) {
        final int? id = d.infirmier.id;
        if (id == null || id == c.demandeurId) continue;
        if (d.infirmier.serviceId != serviceId) continue;
        collegues.add(await _collegue(Role.infirmier, id, d.infirmier.disponible));
      }
    }

    final List<DateTime> jours = RegleConges.joursEnSousEffectif(
      debut: c.debut,
      fin: c.fin,
      collegues: collegues,
    );
    if (jours.isEmpty) return null;
    final String qui = c.role == Role.medecin ? 'médecin' : 'infirmier';
    return 'Refus automatique : le service n\'aurait plus aucun autre $qui '
        'présent le ${RegleConges.resumerJours(jours)}';
  }

  Future<Collegue> _collegue(Role role, int id, bool disponible) async {
    final List<Conge> conges = await _conges.dePersonne(role, id);
    return Collegue(
      disponible: disponible,
      conges: [for (final Conge k in conges) (k.debut, k.fin)],
    );
  }

  /// Validation par l'admin. L'effectif est vérifié à nouveau : si le service
  /// se retrouverait vide, la demande est refusée automatiquement.
  Future<ResultatConge> valider(int id) async {
    final CongeDetail? d = await _conges.parId(id);
    if (d == null) {
      throw const StaffException('Demande introuvable');
    }
    if (d.conge.statut != StatutConge.enAttente) {
      throw const StaffException('Cette demande a déjà été traitée');
    }

    final String? sousEffectif = await _verifierEffectif(d.conge);
    if (sousEffectif != null) {
      await _conges.changerStatut(id, StatutConge.refusee, commentaire: sousEffectif);
      return ResultatConge(validee: false, message: sousEffectif);
    }

    await _conges.changerStatut(id, StatutConge.validee);
    int confies = 0;
    if (d.conge.role == Role.medecin &&
        d.conge.nbJours >= RegleConges.seuilReaffectation) {
      confies = await _confierPatients(d.conge);
    }
    return ResultatConge(
      validee: true,
      message: confies == 0
          ? 'Congé validé'
          : 'Congé validé · $confies patient(s) confié(s) à un collègue',
    );
  }

  /// Patients du médecin absent → collègue du service le moins chargé,
  /// présent pendant toute la période.
  Future<int> _confierPatients(Conge c) async {
    final List<Patient> patients = await _patients.parMedecin(c.demandeurId);
    int n = 0;
    for (final Patient p in patients) {
      final int? patientId = p.id;
      final int? serviceId = p.serviceId;
      if (patientId == null || serviceId == null) continue;
      final int? autre = await _medecins.moinsCharge(
        serviceId,
        exclureId: c.demandeurId,
        du: c.debut,
        au: c.fin,
      );
      if (autre == null) continue;
      await _patients.affecterMedecin(patientId, autre);
      n++;
    }
    return n;
  }

  Future<void> refuser(int id, String motif) async {
    final String m = motif.trim();
    if (m.isEmpty) {
      throw const StaffException('Indiquez le motif du refus');
    }
    final CongeDetail? d = await _conges.parId(id);
    if (d == null || d.conge.statut != StatutConge.enAttente) {
      throw const StaffException('Cette demande a déjà été traitée');
    }
    await _conges.changerStatut(id, StatutConge.refusee, commentaire: m);
  }

  /// Le demandeur annule sa demande : en attente, ou validée mais pas
  /// encore commencée.
  Future<void> annuler(int id, {DateTime? aujourdHui}) async {
    final CongeDetail? d = await _conges.parId(id);
    if (d == null) return;
    final Conge c = d.conge;
    final DateTime jour = RegleConges.jour(aujourdHui ?? DateTime.now());
    final bool possible = c.statut == StatutConge.enAttente ||
        (c.statut == StatutConge.validee && RegleConges.jour(c.debut).isAfter(jour));
    if (!possible) {
      throw const StaffException('Ce congé ne peut plus être annulé');
    }
    await _conges.changerStatut(id, StatutConge.annulee);
  }
}
