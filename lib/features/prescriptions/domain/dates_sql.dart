import '../../../core/utils/formatters.dart';

/// Format des dates stockées par le module.
///
/// - colonnes « date » : 2026-10-09
/// - colonnes « date + heure » : 2026-10-09 08:00:00 (heure locale), même
///   format que datetime() de SQLite, pour pouvoir comparer les textes.
class DatesSql {
  DatesSql._();

  static String date(DateTime d) => Formatters.dateIso(d);

  static String dateHeure(DateTime d) {
    return '${date(d)} ${_deux(d.hour)}:${_deux(d.minute)}:${_deux(d.second)}';
  }

  static DateTime lire(Object? valeur) => DateTime.parse(valeur as String);

  static DateTime? lireOuNull(Object? valeur) {
    if (valeur == null) {
      return null;
    }
    return DateTime.parse(valeur as String);
  }

  /// Minuit du même jour.
  static DateTime jour(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _deux(int v) => v.toString().padLeft(2, '0');
}
