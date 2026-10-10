import 'models/ligne_ordonnance.dart';
import 'models/medicament.dart';
import 'planning_prises.dart';

/// Texte lisible d'une posologie : « 1 comprimé · matin, soir · 30 jours ».
class Posologie {
  Posologie._();

  /// Unité de prise selon la forme du médicament.
  static String unite(String forme, double dose) {
    final String f = forme.toLowerCase();
    final bool pluriel = dose > 1;
    if (f.contains('sirop') || f.contains('buvable')) {
      return 'ml';
    }
    if (f.contains('stylo')) {
      return 'UI';
    }
    if (f.contains('injectable') || f.contains('solution')) {
      return 'ml';
    }
    if (f.contains('aérosol')) {
      return pluriel ? 'bouffées' : 'bouffée';
    }
    if (f.contains('collyre')) {
      return pluriel ? 'gouttes' : 'goutte';
    }
    if (f.contains('pommade')) {
      return pluriel ? 'applications' : 'application';
    }
    return pluriel ? '${f}s' : f;
  }

  /// 1.0 → « 1 », 0.5 → « 0,5 ».
  static String nombre(double v) {
    if (v == v.roundToDouble()) {
      return v.round().toString();
    }
    return v.toString().replaceAll('.', ',');
  }

  /// « matin, soir »
  static String moments(List<String> moments) {
    final List<String> res = [];
    for (final String m in PlanningPrises.trier(moments)) {
      res.add((PlanningPrises.libelles[m] ?? m).toLowerCase());
    }
    return res.join(', ');
  }

  static String texte(LigneOrdonnance l, Medicament m) {
    final String duree = l.dureeJours > 1 ? '${l.dureeJours} jours' : '1 jour';
    return '${nombre(l.dosePrise)} ${unite(m.forme, l.dosePrise)} · ${moments(l.moments)} · $duree';
  }

  /// « 2 boîtes »
  static String boites(int n) => n > 1 ? '$n boîtes' : '$n boîte';
}
