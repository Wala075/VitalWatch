import '../posologie.dart';
import 'ligne_ordonnance.dart';
import 'medicament.dart';
import 'ordonnance.dart';

/// Ordonnance + noms du patient et du médecin (listes, fiche).
class OrdonnanceResume {
  const OrdonnanceResume({
    required this.ordonnance,
    required this.patientNom,
    required this.medecinNom,
    required this.nbLignes,
    this.origineNumero,
  });

  final Ordonnance ordonnance;
  final String patientNom;
  final String medecinNom;
  final int nbLignes;

  /// Numéro de l'ordonnance d'origine (renouvellement, correction).
  final String? origineNumero;
}

/// Ligne d'ordonnance avec son médicament.
class LigneDetail {
  const LigneDetail({required this.ligne, required this.medicament});

  final LigneOrdonnance ligne;
  final Medicament medicament;

  /// « 1 comprimé · matin, soir · 30 jours »
  String get posologie => Posologie.texte(ligne, medicament);
}

/// Résultat des contrôles avant validation.
class ControleValidation {
  const ControleValidation({required this.bloquants, required this.avertissements});

  /// Empêchent la validation.
  final List<String> bloquants;

  /// Le médecin peut valider quand même, après confirmation.
  final List<String> avertissements;

  bool get peutValider => bloquants.isEmpty;
}

/// Médicament en cours de traitement chez un patient (ordonnance active).
class TraitementActif {
  const TraitementActif({
    required this.ordonnanceId,
    required this.numero,
    required this.medecinId,
    required this.medecinNom,
    required this.dci,
    required this.medicament,
  });

  final int ordonnanceId;
  final String numero;
  final int medecinId;
  final String medecinNom;
  final String dci;

  /// « Amlor 5 mg »
  final String medicament;
}
