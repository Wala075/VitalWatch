/// Affichage des montants et des taux du module.
class FormatsPrescriptions {
  FormatsPrescriptions._();

  /// 12.5 → « 12,500 DT » (au millime).
  static String dt(double v) => '${decimal(v)} DT';

  /// 12.5 → « 12,500 » (champ de saisie).
  static String decimal(double v) => v.toStringAsFixed(3).replaceAll('.', ',');

  /// 0.85 → « 85 % ».
  static String taux(double taux) => '${pourcent(taux)} %';

  /// 0.85 → « 85 » ; 0.335 → « 33,5 » (champ de saisie).
  static String pourcent(double taux) {
    final double p = taux * 100;
    if ((p - p.roundToDouble()).abs() < 0.05) {
      return p.round().toString();
    }
    return p.toStringAsFixed(1).replaceAll('.', ',');
  }
}
