import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';

/// Tables du module Rendez-vous, créées par le module lui-même
/// (CREATE TABLE IF NOT EXISTS) pour ne pas modifier app_database.dart.
///
/// Toutes les classes du module passent par [RdvSchema.db] : les tables
/// sont créées au premier accès, puis les données de démo sont ajoutées.
class RdvSchema {
  RdvSchema._();

  static Future<Database>? _pret;

  /// Base prête à l'emploi (tables du module créées).
  static Future<Database> get db => _pret ??= _preparer();

  static Future<Database> _preparer() async {
    final Database db = await AppDatabase.instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS creneaux (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medecin_id INTEGER NOT NULL REFERENCES medecins(id) ON DELETE CASCADE,
        jour INTEGER NOT NULL,
        date TEXT,
        heure_debut INTEGER NOT NULL,
        heure_fin INTEGER NOT NULL,
        recurrent INTEGER NOT NULL DEFAULT 1,
        duree_rdv INTEGER NOT NULL DEFAULT 30
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rendez_vous (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
        medecin_id INTEGER NOT NULL REFERENCES medecins(id) ON DELETE CASCADE,
        date_heure TEXT NOT NULL,
        duree INTEGER NOT NULL DEFAULT 30,
        type TEXT NOT NULL,
        motif TEXT NOT NULL,
        statut TEXT NOT NULL,
        priorite TEXT NOT NULL DEFAULT 'normale',
        lien_visio TEXT,
        cree_par INTEGER,
        motif_annulation TEXT,
        date_creation TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS consultations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rdv_id INTEGER NOT NULL UNIQUE REFERENCES rendez_vous(id) ON DELETE CASCADE,
        diagnostic TEXT NOT NULL,
        compte_rendu TEXT NOT NULL,
        resume_ia TEXT,
        debut TEXT,
        fin TEXT,
        duree_reelle INTEGER
      )
    ''');
    // Notifications pour le médecin (appel urgent d'un patient).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications_rdv (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rdv_id INTEGER NOT NULL REFERENCES rendez_vous(id) ON DELETE CASCADE,
        medecin_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        lu INTEGER NOT NULL DEFAULT 0,
        date_creation TEXT NOT NULL
      )
    ''');
    // Notifications pour le patient (RDV pris pour lui par le personnel).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications_patient (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rdv_id INTEGER NOT NULL REFERENCES rendez_vous(id) ON DELETE CASCADE,
        patient_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        lu INTEGER NOT NULL DEFAULT 0,
        date_creation TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_rdv_medecin ON rendez_vous(medecin_id, date_heure)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_rdv_patient ON rendez_vous(patient_id, date_heure)',
    );
    await _donneesDemo(db);
    return db;
  }

  /// Créneaux et RDV de démonstration (une seule fois, si la table est vide).
  static Future<void> _donneesDemo(Database db) async {
    final List<Map<String, Object?>> n =
        await db.rawQuery('SELECT COUNT(*) AS n FROM creneaux');
    if (((n.first['n'] as int?) ?? 0) > 0) {
      return;
    }
    final List<Map<String, Object?>> medecins =
        await db.query('medecins', columns: ['id']);
    if (medecins.isEmpty) {
      return;
    }

    final Batch b = db.batch();
    for (final Map<String, Object?> m in medecins) {
      final int id = m['id'] as int;
      // Lundi -> vendredi : 8h30-12h30 et 14h-17h, RDV de 30 min.
      for (int jour = 1; jour <= 5; jour++) {
        b.insert('creneaux', {
          'medecin_id': id,
          'jour': jour,
          'heure_debut': 8 * 60 + 30,
          'heure_fin': 12 * 60 + 30,
          'recurrent': 1,
          'duree_rdv': 30,
        });
        b.insert('creneaux', {
          'medecin_id': id,
          'jour': jour,
          'heure_debut': 14 * 60,
          'heure_fin': 17 * 60,
          'recurrent': 1,
          'duree_rdv': 30,
        });
      }
      // Samedi matin
      b.insert('creneaux', {
        'medecin_id': id,
        'jour': 6,
        'heure_debut': 9 * 60,
        'heure_fin': 12 * 60,
        'recurrent': 1,
        'duree_rdv': 30,
      });
    }

    // Quelques RDV de démo pour les patients 1 et 2 (s'ils existent).
    final List<Map<String, Object?>> patients = await db.query(
      'patients',
      columns: ['id', 'medecin_id'],
      where: 'id IN (1, 2) AND medecin_id IS NOT NULL',
    );
    final DateTime n0 = DateTime.now();
    DateTime jour(int decalage, int h, int min) =>
        DateTime(n0.year, n0.month, n0.day + decalage, h, min);

    for (final Map<String, Object?> p in patients) {
      final int pid = p['id'] as int;
      final int mid = p['medecin_id'] as int;
      final bool premier = pid == 1;
      b.insert('rendez_vous', _rdv(pid, mid, jour(premier ? 1 : 2, 10, 0),
          premier ? 'visio' : 'presentiel', 'Contrôle tension artérielle', 'confirme'));
      b.insert('rendez_vous', _rdv(pid, mid, jour(-10, 9, 0), 'presentiel',
          'Bilan cardiaque annuel', 'termine'));
      b.insert('rendez_vous', _rdv(pid, mid, jour(-20, 15, 0), 'presentiel',
          'Douleurs thoraciques', premier ? 'absent' : 'termine'));
    }
    await b.commit(noResult: true);
  }

  static Map<String, Object?> _rdv(
    int patientId,
    int medecinId,
    DateTime date,
    String type,
    String motif,
    String statut,
  ) {
    return {
      'patient_id': patientId,
      'medecin_id': medecinId,
      'date_heure': date.toIso8601String(),
      'duree': 30,
      'type': type,
      'motif': motif,
      'statut': statut,
      'priorite': 'normale',
      'date_creation': DateTime.now().toIso8601String(),
    };
  }
}
