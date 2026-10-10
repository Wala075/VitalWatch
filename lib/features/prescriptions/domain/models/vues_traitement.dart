import '../posologie.dart';
import 'ligne_ordonnance.dart';
import 'ordonnance.dart';
import 'prise.dart';

/// Une prise du planning avec son médicament (écran « Aujourd'hui »).
class PrisePlanifiee {
  const PrisePlanifiee({
    required this.prise,
    required this.medicament,
    required this.forme,
    required this.dose,
    required this.numero,
    this.instructions,
  });

  final Prise prise;

  /// « Doliprane 1000 mg »
  final String medicament;
  final String forme;
  final double dose;
  final String numero;
  final String? instructions;

  /// « 1 comprimé »
  String get quantite => '${Posologie.nombre(dose)} ${Posologie.unite(forme, dose)}';
}

/// Observance d'une journée : prises faites / prises échues.
class ObservanceJour {
  const ObservanceJour({required this.jour, required this.faites, required this.echues});

  final DateTime jour;
  final int faites;
  final int echues;

  /// Entre 0 et 1 ; null si aucune prise n'était prévue.
  double? get taux => echues == 0 ? null : faites / echues;
}

/// Stock restant d'un médicament délivré (métier 4).
class StockTraitement {
  const StockTraitement({
    required this.ordonnance,
    required this.ligne,
    required this.medicament,
    required this.forme,
    required this.unitesParBoite,
    required this.prisesFaites,
  });

  final Ordonnance ordonnance;
  final LigneOrdonnance ligne;
  final String medicament;
  final String forme;
  final int unitesParBoite;
  final int prisesFaites;

  /// Seuil d'alerte : 3 jours ou moins.
  static const int seuilJours = 3;

  /// Boîtes délivrées × unités par boîte − prises faites × dose.
  double get stock {
    final double s = ligne.quantiteDelivree * unitesParBoite - prisesFaites * ligne.dosePrise;
    return s < 0 ? 0 : s;
  }

  /// Stock ÷ (dose × prises par jour).
  double get joursRestants {
    final double parJour = ligne.dosePrise * ligne.prisesParJour;
    return parJour <= 0 ? 0 : stock / parJour;
  }

  bool get alerte => joursRestants <= seuilJours;

  /// « 4 comprimés »
  String get stockTexte => '${Posologie.nombre(stock.floorToDouble())} ${Posologie.unite(forme, stock)}';
}
