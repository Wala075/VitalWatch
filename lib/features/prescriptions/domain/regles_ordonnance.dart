import 'models/medicament.dart';
import 'posologie.dart';

/// Contrôles de saisie des ordonnances (sans base de données : testables).
/// Renvoient null si tout est correct, sinon le message du cahier des charges.
class ReglesOrdonnance {
  ReglesOrdonnance._();

  static const int motifMinimum = 10;
  static const int renouvellementsMax = 6;

  static String? ligne({
    required Medicament medicament,
    required double dosePrise,
    required List<String> moments,
    required int dureeJours,
  }) {
    if (dosePrise <= 0) {
      return 'La dose par prise doit être supérieure à 0';
    }
    if (moments.isEmpty || moments.length > 6) {
      return 'Entre 1 et 6 prises par jour';
    }
    if (dureeJours < 1 || dureeJours > 365) {
      return 'Durée entre 1 et 365 jours';
    }
    final double? max = medicament.doseMaxJour;
    if (max != null && dosePrise * moments.length > max + 1e-9) {
      return 'Dose journalière maximale dépassée '
          '(max ${Posologie.nombre(max)} ${Posologie.unite(medicament.forme, max)})';
    }
    return null;
  }

  static String? dates(DateTime emission, DateTime expiration) {
    if (!expiration.isAfter(emission)) {
      return "La date d'expiration doit suivre la date d'émission";
    }
    return null;
  }

  static String? renouvellements(int nb) {
    if (nb < 0 || nb > renouvellementsMax) {
      return 'Entre 0 et $renouvellementsMax renouvellements';
    }
    return null;
  }

  static String? motifAnnulation(String? motif) {
    if ((motif ?? '').trim().length < motifMinimum) {
      return "Indiquez le motif de l'annulation (au moins $motifMinimum caractères)";
    }
    return null;
  }
}
