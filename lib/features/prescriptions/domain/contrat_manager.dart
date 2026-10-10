import '../data/apci_repository.dart';
import '../data/assurance_repository.dart';
import '../data/contrat_assurance_repository.dart';
import 'models/assurance.dart';
import 'models/contrat_assurance.dart';
import 'prescriptions_exception.dart';

/// Contrats d'assurance des patients (créés depuis la fiche patient).
/// Pas de suppression : un contrat se résilie (date de fin).
class ContratManager {
  ContratManager({
    ContratAssuranceRepository? contrats,
    AssuranceRepository? assurances,
    ApciRepository? apci,
  })  : _contrats = contrats ?? ContratAssuranceRepository(),
        _assurances = assurances ?? AssuranceRepository(),
        _apci = apci ?? ApciRepository();

  final ContratAssuranceRepository _contrats;
  final AssuranceRepository _assurances;
  final ApciRepository _apci;

  /// Longueur du numéro d'adhérent (paramétrable).
  static const int longueurNumero = 8;

  static final RegExp _chiffres = RegExp(r'^[0-9]+$');

  /// Contrôles sans base de données (testables).
  static String? verifier(ContratAssurance c) {
    final String numero = c.numeroAdherent.trim();
    if (!_chiffres.hasMatch(numero) || numero.length != longueurNumero) {
      return "Numéro d'adhérent invalide ($longueurNumero chiffres)";
    }
    final DateTime? fin = c.dateFin;
    if (fin != null && !fin.isAfter(c.dateDebut)) {
      return 'La fin du contrat doit suivre son début';
    }
    final String? code = c.codeApci;
    if (c.apci && (code == null || code.trim().isEmpty)) {
      return 'Choisissez la maladie APCI du contrat';
    }
    return null;
  }

  Future<int> enregistrer(ContratAssurance c) async {
    final String? erreur = verifier(c);
    if (erreur != null) {
      throw PrescriptionsException(erreur);
    }
    final Assurance? assurance = await _assurances.parId(c.assuranceId);
    if (assurance == null) {
      throw const PrescriptionsException('Assurance introuvable');
    }
    if (c.apci && !assurance.estObligatoire) {
      throw const PrescriptionsException("L'APCI est une prise en charge de la CNAM");
    }
    final String? code = c.codeApci;
    if (c.apci && code != null && await _apci.parCode(code) == null) {
      throw PrescriptionsException("Le code $code n'est pas dans la liste APCI");
    }
    if (assurance.estObligatoire &&
        c.estActifLe(DateTime.now()) &&
        await _contrats.aUnContratCnamActif(c.patientId, DateTime.now(), exclureId: c.id)) {
      throw const PrescriptionsException('Ce patient a déjà un contrat CNAM actif');
    }
    if (await _contrats.numeroExiste(c.assuranceId, c.numeroAdherent, c.beneficiaire, exclureId: c.id)) {
      throw const PrescriptionsException(
        'Ce numéro d’adhérent existe déjà pour ce bénéficiaire chez cette assurance',
      );
    }

    final int? id = c.id;
    if (id == null) {
      return _contrats.inserer(c);
    }
    await _contrats.modifier(c);
    return id;
  }

  /// Résiliation au lieu de suppression.
  Future<void> resilier(ContratAssurance c, DateTime dateFin) async {
    if (!dateFin.isAfter(c.dateDebut)) {
      throw const PrescriptionsException('La fin du contrat doit suivre son début');
    }
    await _contrats.resilier(c.id!, dateFin);
  }
}
