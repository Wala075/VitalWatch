import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../domain/protection_connexion.dart';

/// Échecs de connexion par email (table `tentatives_connexion`, créée au
/// premier accès : pas besoin de changer la version de la base).
class TentativeRepository {
  static Future<void>? _creation;

  Future<Database> get _db async {
    final Database db = await AppDatabase.instance.database;
    await (_creation ??= db.execute('''
      CREATE TABLE IF NOT EXISTS tentatives_connexion (
        email TEXT PRIMARY KEY,
        echecs INTEGER NOT NULL DEFAULT 0,
        bloque_jusqua TEXT
      )
    '''));
    return db;
  }

  Future<TentativesConnexion> lire(String email) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'tentatives_connexion',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const TentativesConnexion();
    }
    final String? fin = rows.first['bloque_jusqua'] as String?;
    return TentativesConnexion(
      echecs: (rows.first['echecs'] as int?) ?? 0,
      bloqueJusqua: fin == null ? null : DateTime.tryParse(fin),
    );
  }

  Future<void> enregistrer(String email, TentativesConnexion t) async {
    final Database db = await _db;
    await db.insert(
      'tentatives_connexion',
      {
        'email': email,
        'echecs': t.echecs,
        'bloque_jusqua': t.bloqueJusqua?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> effacer(String email) async {
    final Database db = await _db;
    await db.delete(
      'tentatives_connexion',
      where: 'email = ?',
      whereArgs: [email],
    );
  }
}
