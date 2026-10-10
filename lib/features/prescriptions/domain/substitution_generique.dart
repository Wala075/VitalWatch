import '../data/api/rxnorm_api.dart';
import '../data/medicament_repository.dart';
import 'calcul_prise_en_charge.dart';
import 'models/medicament.dart';
import 'remboursement_manager.dart';

/// Un équivalent moins cher et l'économie qu'il permet.
class Equivalent {
  const Equivalent({
    required this.medicament,
    required this.economiePatient,
    required this.economieAssurance,
  });

  final Medicament medicament;
  final double economiePatient;
  final double economieAssurance;
}

/// Résultat de la recherche de substitution.
class PropositionSubstitution {
  const PropositionSubstitution({
    required this.equivalents,
    this.rxcui,
    this.dosageConfirme = false,
    this.remarque,
  });

  /// Du moins cher au plus cher (catalogue local).
  final List<Equivalent> equivalents;

  /// Identifiant RxNorm de la DCI (null si RxNorm ne la connaît pas).
  final String? rxcui;

  /// RxNorm connaît ce dosage pour cet ingrédient.
  final bool dosageConfirme;
  final String? remarque;
}

/// Métier 6 : substitution générique.
/// RxNorm normalise la DCI et confirme le dosage ; les équivalents (même
/// DCI, même dosage, même forme) viennent du catalogue local, triés par prix
/// public, puisque RxNorm ne connaît aucun prix.
class SubstitutionGenerique {
  SubstitutionGenerique({
    RxNormApi? api,
    MedicamentRepository? medicaments,
    RemboursementManager? remboursement,
  })  : _api = api ?? RxNormApi(),
        _medicaments = medicaments ?? MedicamentRepository(),
        _remboursement = remboursement ?? RemboursementManager();

  final RxNormApi _api;
  final MedicamentRepository _medicaments;
  final RemboursementManager _remboursement;

  /// DCI françaises → noms RxNorm (américains).
  static const Map<String, String> dciAnglais = {
    'paracétamol': 'acetaminophen',
    'metformine': 'metformin',
    'atorvastatine': 'atorvastatin',
    'amlodipine': 'amlodipine',
    'amoxicilline': 'amoxicillin',
    'oméprazole': 'omeprazole',
    'clopidogrel': 'clopidogrel',
    'lévothyroxine': 'levothyroxine',
    'salbutamol': 'albuterol',
    'insuline glargine': 'insulin glargine',
    'ibuprofène': 'ibuprofen',
    'acide acétylsalicylique': 'aspirin',
    'azithromycine': 'azithromycin',
    'oxomémazine': 'oxomemazine',
  };

  static String nomAnglais(String dci) {
    final String d = dci.trim().toLowerCase();
    return dciAnglais[d] ?? d;
  }

  /// « 5 mg » → « 5 MG », « 1 g » → « 1000 MG », « 100 µg » → « 0.1 MG ».
  static String? dosageRxNorm(String dosage) {
    final RegExp motif = RegExp(r'([0-9]+(?:[.,][0-9]+)?)\s*(mg|g|µg|mcg)', caseSensitive: false);
    final RegExpMatch? m = motif.firstMatch(dosage);
    if (m == null) {
      return null;
    }
    final double? valeur = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    if (valeur == null) {
      return null;
    }
    final String unite = m.group(2)!.toLowerCase();
    double mg = valeur;
    if (unite == 'g') {
      mg = valeur * 1000;
    } else if (unite == 'µg' || unite == 'mcg') {
      mg = valeur / 1000;
    }
    final String texte = mg == mg.roundToDouble() ? mg.round().toString() : mg.toString();
    return '$texte MG';
  }

  /// Équivalents moins chers de [m]. Avec [patientId], l'économie est
  /// calculée avec ses vrais taux (métier 8) ; sinon, écart de prix.
  Future<PropositionSubstitution> proposer(Medicament m, {int? patientId, int boites = 1}) async {
    final List<Medicament> locaux = [];
    for (final Medicament e in await _medicaments.equivalents(m)) {
      if (e.prixPublic < m.prixPublic) {
        locaux.add(e);
      }
    }

    // RxNorm : DCI normalisée (mise en cache dans medicament.rxcui) et dosage.
    String? rxcui = m.rxcui;
    bool dosageConfirme = false;
    String? remarque;
    try {
      rxcui ??= await _api.rxcuiIngredient(nomAnglais(m.dci));
      if (rxcui != null) {
        if (m.rxcui == null && m.id != null) {
          await _medicaments.mettreAJourRxcui(m.id!, rxcui);
        }
        final String? dosage = dosageRxNorm(m.dosage);
        if (dosage != null) {
          for (final String nom in await _api.produitsCliniques(rxcui)) {
            if (nom.toUpperCase().contains(' $dosage')) {
              dosageConfirme = true;
              break;
            }
          }
        }
      } else {
        remarque = 'DCI inconnue de RxNorm : équivalents du catalogue local';
      }
    } catch (_) {
      remarque = 'RxNorm injoignable : équivalents du catalogue local';
    }

    final List<Equivalent> equivalents = [];
    DetailLigne? origine;
    if (patientId != null) {
      origine = await _remboursement.simulerMedicament(patientId, m, boites);
    }
    for (final Medicament e in locaux) {
      if (origine == null || patientId == null) {
        final double ecart = CalculPriseEnCharge.arrondi((m.prixPublic - e.prixPublic) * boites);
        equivalents.add(Equivalent(medicament: e, economiePatient: ecart, economieAssurance: 0));
      } else {
        final DetailLigne g = await _remboursement.simulerMedicament(patientId, e, boites);
        equivalents.add(Equivalent(
          medicament: e,
          economiePatient: CalculPriseEnCharge.arrondi(origine.resteACharge - g.resteACharge),
          economieAssurance: CalculPriseEnCharge.arrondi(
            (origine.partCnam + origine.partMutuelle) - (g.partCnam + g.partMutuelle),
          ),
        ));
      }
    }
    return PropositionSubstitution(
      equivalents: equivalents,
      rxcui: rxcui,
      dosageConfirme: dosageConfirme,
      remarque: remarque,
    );
  }
}
