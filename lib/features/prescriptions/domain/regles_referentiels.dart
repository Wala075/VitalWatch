import 'models/assurance.dart';
import 'models/medicament.dart';
import 'models/taux_couverture.dart';

/// Contrôles de saisie des référentiels (sans base de données : testables).
/// Renvoient null si tout est correct, sinon le message à afficher.
class ReglesReferentiels {
  ReglesReferentiels._();

  static String? medicament(Medicament m) {
    if (m.nomCommercial.trim().isEmpty) {
      return 'Le nom commercial est obligatoire';
    }
    if (m.dci.trim().isEmpty) {
      return 'La DCI est obligatoire';
    }
    if (m.forme.trim().isEmpty || m.dosage.trim().isEmpty) {
      return 'La forme et le dosage sont obligatoires';
    }
    if (m.unitesParBoite < 1) {
      return "Le nombre d'unités par boîte doit être supérieur à 0";
    }
    final double? doseMax = m.doseMaxJour;
    if (doseMax != null && doseMax <= 0) {
      return 'La dose maximale par jour doit être supérieure à 0';
    }
    if (m.prixPublic < 0) {
      return 'Le prix public ne peut pas être négatif';
    }
    final double? reference = m.prixReference;
    if (reference != null && reference < 0) {
      return 'Le prix de référence ne peut pas être négatif';
    }
    if (reference != null && reference > m.prixPublic) {
      return 'Le prix de référence ne peut pas dépasser le prix public';
    }
    return null;
  }

  static String? assurance(Assurance a, List<TauxCouverture> taux) {
    if (a.nom.trim().isEmpty) {
      return "Le nom de l'assurance est obligatoire";
    }
    final double? plafond = a.plafondAnnuel;
    if (plafond != null && plafond < 0) {
      return 'Le plafond annuel ne peut pas être négatif';
    }
    if (a.delaiReponseJours < 1) {
      return 'Le délai de réponse doit être d’au moins 1 jour';
    }
    if (taux.isEmpty) {
      return 'Indiquez au moins un taux de prise en charge';
    }

    final Set<String> vues = {};
    for (final TauxCouverture t in taux) {
      if (t.taux < 0 || t.taux > 1) {
        return 'Chaque taux doit être compris entre 0 et 100 %';
      }
      if (!vues.add(t.categorie)) {
        return 'Une catégorie ne peut avoir qu’un seul taux';
      }
      if (a.type == TypeAssurance.cnam && t.categorie == TauxCouverture.tous) {
        return 'La CNAM rembourse par catégorie de médicament : '
            'renseignez les taux catégorie par catégorie';
      }
    }
    return null;
  }
}
