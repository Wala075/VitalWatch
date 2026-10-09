import 'package:sqflite/sqflite.dart';

/// Numéros lisibles par année : ORD-2026-0001, REM-2026-0001.
class Numerotation {
  Numerotation._();

  static Future<String> prochain(
    DatabaseExecutor e, {
    required String table,
    required String prefixe,
    required int annee,
  }) async {
    final String debut = '$prefixe-$annee-';
    final List<Map<String, Object?>> rows = await e.query(
      table,
      columns: ['numero'],
      where: 'numero LIKE ?',
      whereArgs: ['$debut%'],
      orderBy: 'numero DESC',
      limit: 1,
    );

    int suivant = 1;
    if (rows.isNotEmpty) {
      final String dernier = rows.first['numero'] as String;
      final int? n = int.tryParse(dernier.substring(debut.length));
      if (n != null) {
        suivant = n + 1;
      }
    }
    return '$debut${suivant.toString().padLeft(4, '0')}';
  }
}
