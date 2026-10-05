import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../models/utilisateur.dart';
import '../utils/password_hasher.dart';

/// Base SQLite locale partagée par tous les modules.
/// Pour ajouter des tables : les créer dans [_onCreate], incrémenter [_version]
/// et ajouter la migration dans onUpgrade.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _fichier = 'vitalwatch.db';
  static const int _version = 2;

  Future<Database>? _ouverture;

  Future<Database> get database => _ouverture ??= _ouvrir();

  Future<Database> _ouvrir() async {
    final String chemin = p.join(await getDatabasesPath(), _fichier);
    return openDatabase(
      chemin,
      version: _version,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ===== Module 1 : Services & Personnel =====
    await db.execute('''
      CREATE TABLE services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL UNIQUE,
        chef_service_id INTEGER REFERENCES medecins(id) ON DELETE SET NULL,
        etage INTEGER,
        telephone TEXT NOT NULL,
        capacite INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE medecins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        matricule TEXT NOT NULL UNIQUE,
        specialite TEXT NOT NULL,
        telephone TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        photo TEXT,
        service_id INTEGER REFERENCES services(id) ON DELETE SET NULL,
        disponible INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE patients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        cin TEXT NOT NULL UNIQUE,
        date_naissance TEXT NOT NULL,
        sexe TEXT NOT NULL,
        telephone TEXT NOT NULL,
        adresse TEXT,
        groupe_sanguin TEXT,
        email TEXT,
        contact_urgence_nom TEXT,
        contact_urgence_tel TEXT,
        service_id INTEGER REFERENCES services(id) ON DELETE SET NULL,
        medecin_id INTEGER REFERENCES medecins(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE utilisateurs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        mot_de_passe_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        ref_id INTEGER,
        nom TEXT,
        prenom TEXT,
        actif INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await _creerTableHoraires(db);

    await _donneesDemo(db);
  }

  /// Migration des bases déjà installées (version 1 → 2).
  Future<void> _onUpgrade(Database db, int ancienne, int nouvelle) async {
    if (ancienne < 2) {
      await _creerTableHoraires(db);
      final List<Map<String, Object?>> medecins =
          await db.query('medecins', columns: ['id']);
      final Batch b = db.batch();
      for (final Map<String, Object?> m in medecins) {
        final int id = m['id'] as int;
        for (int jour = 1; jour <= 5; jour++) {
          b.insert('horaires_medecins', _horaire(id, jour, 9 * 60, 17 * 60));
        }
      }
      await b.commit(noResult: true);
    }
  }

  // ===== Module 1 : horaires de consultation des médecins (version 2) =====
  // jour : 1 = lundi … 7 = dimanche ; debut / fin : minutes depuis minuit.
  Future<void> _creerTableHoraires(Database db) async {
    await db.execute('''
      CREATE TABLE horaires_medecins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medecin_id INTEGER NOT NULL REFERENCES medecins(id) ON DELETE CASCADE,
        jour INTEGER NOT NULL,
        debut INTEGER NOT NULL,
        fin INTEGER NOT NULL
      )
    ''');
  }

  Map<String, Object?> _horaire(int medecinId, int jour, int debut, int fin) {
    return {'medecin_id': medecinId, 'jour': jour, 'debut': debut, 'fin': fin};
  }

  /// Données de démonstration (créées une seule fois, au premier lancement).
  Future<void> _donneesDemo(Database db) async {
    final Batch b = db.batch();

    b.insert('services', {'id': 1, 'nom': 'Cardiologie', 'etage': 2, 'telephone': '+21673000101', 'capacite': 30});
    b.insert('services', {'id': 2, 'nom': 'Urgences', 'etage': 0, 'telephone': '+21673000102', 'capacite': 50});
    b.insert('services', {'id': 3, 'nom': 'Pédiatrie', 'etage': 1, 'telephone': '+21673000103', 'capacite': 25});

    b.insert('medecins', {'id': 1, 'nom': 'Ben Salah', 'prenom': 'Amine', 'matricule': 'MAT-1001', 'specialite': 'Cardiologie', 'telephone': '+21622123456', 'email': 'medecin@vitalwatch.tn', 'service_id': 1, 'disponible': 1});
    b.insert('medecins', {'id': 2, 'nom': 'Gharbi', 'prenom': 'Leila', 'matricule': 'MAT-1002', 'specialite': 'Cardiologie', 'telephone': '+21622654321', 'email': 'leila.gharbi@vitalwatch.tn', 'service_id': 1, 'disponible': 1});
    b.insert('medecins', {'id': 3, 'nom': 'Jaziri', 'prenom': 'Karim', 'matricule': 'MAT-1003', 'specialite': 'Médecine d\'urgence', 'telephone': '+21698111222', 'email': 'karim.jaziri@vitalwatch.tn', 'service_id': 2, 'disponible': 1});
    b.insert('medecins', {'id': 4, 'nom': 'Mansour', 'prenom': 'Nour', 'matricule': 'MAT-1004', 'specialite': 'Pédiatrie', 'telephone': '+21650333444', 'email': 'nour.mansour@vitalwatch.tn', 'service_id': 3, 'disponible': 1});

    b.update('services', {'chef_service_id': 1}, where: 'id = ?', whereArgs: [1]);
    b.update('services', {'chef_service_id': 3}, where: 'id = ?', whereArgs: [2]);
    b.update('services', {'chef_service_id': 4}, where: 'id = ?', whereArgs: [3]);

    b.insert('patients', {'id': 1, 'nom': 'Trabelsi', 'prenom': 'Sarra', 'cin': '09876543', 'date_naissance': '1990-05-14', 'sexe': 'F', 'telephone': '+21655123456', 'adresse': 'Sousse', 'groupe_sanguin': 'A+', 'email': 'patient@vitalwatch.tn', 'contact_urgence_nom': 'Mohamed Trabelsi', 'contact_urgence_tel': '+21655987654', 'service_id': 1, 'medecin_id': 1});
    b.insert('patients', {'id': 2, 'nom': 'Hammami', 'prenom': 'Youssef', 'cin': '11223344', 'date_naissance': '1975-11-02', 'sexe': 'M', 'telephone': '+21697456123', 'adresse': 'Monastir', 'groupe_sanguin': 'O+', 'service_id': 1, 'medecin_id': 2});
    b.insert('patients', {'id': 3, 'nom': 'Kefi', 'prenom': 'Ines', 'cin': '07654321', 'date_naissance': '2018-03-20', 'sexe': 'F', 'telephone': '+21620789456', 'adresse': 'Sousse', 'groupe_sanguin': 'B+', 'contact_urgence_nom': 'Sami Kefi', 'contact_urgence_tel': '+21620111333', 'service_id': 3, 'medecin_id': 4});

    b.insert('utilisateurs', _compte('admin@vitalwatch.tn', 'admin123', Role.admin, null, 'Admin', 'Système'));
    b.insert('utilisateurs', _compte('medecin@vitalwatch.tn', 'medecin123', Role.medecin, 1, 'Ben Salah', 'Amine'));
    b.insert('utilisateurs', _compte('leila.gharbi@vitalwatch.tn', 'medecin123', Role.medecin, 2, 'Gharbi', 'Leila'));
    b.insert('utilisateurs', _compte('karim.jaziri@vitalwatch.tn', 'medecin123', Role.medecin, 3, 'Jaziri', 'Karim'));
    b.insert('utilisateurs', _compte('nour.mansour@vitalwatch.tn', 'medecin123', Role.medecin, 4, 'Mansour', 'Nour'));
    b.insert('utilisateurs', _compte('infirmier@vitalwatch.tn', 'infirmier123', Role.infirmier, null, 'Saidi', 'Rim'));
    b.insert('utilisateurs', _compte('patient@vitalwatch.tn', 'patient123', Role.patient, 1, 'Trabelsi', 'Sarra'));

    // Horaires de consultation de démonstration
    for (int j = 1; j <= 5; j++) {
      b.insert('horaires_medecins', _horaire(1, j, 8 * 60, 14 * 60));
    }
    for (final int j in [1, 3, 4]) {
      b.insert('horaires_medecins', _horaire(2, j, 13 * 60, 19 * 60));
    }
    b.insert('horaires_medecins', _horaire(2, 6, 9 * 60, 13 * 60));
    for (int j = 1; j <= 7; j++) {
      b.insert('horaires_medecins', _horaire(3, j, 8 * 60, 20 * 60));
    }
    for (int j = 2; j <= 6; j++) {
      b.insert('horaires_medecins', _horaire(4, j, 9 * 60, 17 * 60));
    }

    await b.commit(noResult: true);
  }

  Map<String, Object?> _compte(
    String email,
    String motDePasse,
    Role role,
    int? refId,
    String nom,
    String prenom,
  ) {
    return {
      'email': email,
      'mot_de_passe_hash': PasswordHasher.hacher(motDePasse),
      'role': role.name,
      'ref_id': refId,
      'nom': nom,
      'prenom': prenom,
      'actif': 1,
    };
  }
}
