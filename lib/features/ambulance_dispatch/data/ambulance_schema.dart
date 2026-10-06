import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../../../core/utils/password_hasher.dart';
import '../../../models/utilisateur.dart';
import '../domain/haversine.dart';
import '../domain/hopitaux.dart';
import '../domain/models/intervention.dart';

/// Tables du module 3 (Ambulances & Interventions).
///
/// Créées ici avec « IF NOT EXISTS » au premier accès : le module reste
/// autonome et n'oblige pas à modifier app_database.dart (fichier commun).
class AmbulanceSchema {
  AmbulanceSchema._();

  static Future<void>? _initialisation;

  static Future<Database> get database async {
    final Database db = await AppDatabase.instance.database;
    Future<void>? init = _initialisation;
    if (init == null) {
      init = _initialiser(db);
      _initialisation = init;
    }
    try {
      await init;
    } catch (e) {
      _initialisation = null;
      rethrow;
    }
    return db;
  }

  static Future<void> _initialiser(Database db) async {
    await db.transaction((Transaction txn) async {
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS ambulances (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          immatriculation TEXT NOT NULL UNIQUE,
          type TEXT NOT NULL,
          statut TEXT NOT NULL DEFAULT 'disponible',
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          kilometrage INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS ambulanciers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nom TEXT NOT NULL,
          role TEXT NOT NULL,
          telephone TEXT NOT NULL,
          disponible INTEGER NOT NULL DEFAULT 1,
          ambulance_id INTEGER REFERENCES ambulances(id) ON DELETE SET NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS interventions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ambulance_id INTEGER REFERENCES ambulances(id) ON DELETE SET NULL,
          patient_id INTEGER REFERENCES patients(id) ON DELETE SET NULL,
          alerte_id INTEGER,
          adresse TEXT NOT NULL,
          lat REAL NOT NULL,
          lng REAL NOT NULL,
          gravite TEXT NOT NULL,
          statut TEXT NOT NULL,
          origine TEXT NOT NULL DEFAULT 'appel',
          heure_appel TEXT NOT NULL,
          heure_depart TEXT,
          heure_arrivee TEXT,
          hopital_destination TEXT
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS maintenances (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ambulance_id INTEGER NOT NULL REFERENCES ambulances(id) ON DELETE CASCADE,
          type TEXT NOT NULL,
          date TEXT NOT NULL,
          cout REAL NOT NULL DEFAULT 0,
          prochain_entretien_km INTEGER,
          statut TEXT NOT NULL DEFAULT 'terminee'
        )
      ''');
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_interventions_statut ON interventions(statut)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_maintenances_ambulance ON maintenances(ambulance_id)',
      );
      // Rythme cardiaque : le téléphone du patient (montre) écrit,
      // le personnel lit. Une mesure par patient et par horodatage.
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mesures_cardiaques (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
          bpm INTEGER NOT NULL,
          date TEXT NOT NULL,
          source TEXT NOT NULL DEFAULT '',
          simulee INTEGER NOT NULL DEFAULT 0,
          UNIQUE (patient_id, date)
        )
      ''');
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_mesures_patient_date ON mesures_cardiaques(patient_id, date)',
      );
      // Seuils d'alerte fixés par le médecin pour chaque patient.
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS seuils_cardiaques (
          patient_id INTEGER PRIMARY KEY REFERENCES patients(id) ON DELETE CASCADE,
          min INTEGER NOT NULL,
          max INTEGER NOT NULL,
          modifie_le TEXT NOT NULL
        )
      ''');

      final int nb = Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM ambulances'),
          ) ??
          0;
      if (nb == 0) {
        await _donneesDemo(txn);
      }
      await _flotteNationale(txn);
    });
  }

  // =====================================================================
  // Couverture nationale : bases du Grand Tunis, Sfax et Nabeul (avec leur
  // équipage), pour qu'une ambulance proche vienne à la vraie position du
  // patient. Ajoutées une seule fois, y compris sur une base déjà remplie
  // (contrôle par immatriculation).
  // =====================================================================

  static const List<_BaseNationale> _basesNationales = [
    _BaseNationale('233 TU 4410', 'C', 36.8030, 10.1560, 38400, 'SAMU Tunis (La Rabta)', [
      ['Mehdi Gharbi', 'conducteur', '+21698310421'],
      ['Ines Zribi', 'medecin', '+21622418503'],
      ['Rami Jaziri', 'infirmier', '+21655207334'],
    ]),
    _BaseNationale('228 TU 6175', 'B', 36.8935, 10.1880, 51200, 'Ariana (El Ghazala)', [
      ['Aymen Trabelsi', 'conducteur', '+21697541260'],
      ['Salma Bouzid', 'secouriste', '+21624630918'],
    ]),
    _BaseNationale('219 TU 3352', 'A', 36.8150, 10.1810, 97300, 'Tunis (Lafayette)', [
      ['Bilel Hammami', 'conducteur', '+21650872145'],
      ['Nour Ben Salem', 'secouriste', '+21699114386'],
    ]),
    _BaseNationale('241 TU 0937', 'B', 36.8780, 10.3180, 64800, 'La Marsa', [
      ['Yassine Mansour', 'conducteur', '+21693205571'],
      ['Rania Kefi', 'infirmier', '+21628360492'],
    ]),
    _BaseNationale('236 TU 8814', 'B', 36.7540, 10.2280, 72650, 'Ben Arous', [
      ['Hamdi Saidi', 'conducteur', '+21656148830'],
      ['Olfa Ayadi', 'secouriste', '+21621907764'],
    ]),
    _BaseNationale('226 TU 5068', 'C', 34.7410, 10.7600, 45100, 'Sfax', [
      ['Slim Kammoun', 'conducteur', '+21698652017'],
      ['Mariem Ellouze', 'medecin', '+21623771450'],
      ['Fedi Chaabane', 'infirmier', '+21654093286'],
    ]),
    _BaseNationale('231 TU 2741', 'B', 36.4510, 10.7350, 88900, 'Nabeul', [
      ['Anis Bahri', 'conducteur', '+21697328815'],
      ['Hela Mzoughi', 'secouriste', '+21625584037'],
    ]),
  ];

  static Future<void> _flotteNationale(Transaction txn) async {
    for (final _BaseNationale b in _basesNationales) {
      final List<Map<String, Object?>> existe = await txn.query(
        'ambulances',
        columns: ['id'],
        where: 'immatriculation = ?',
        whereArgs: [b.immatriculation],
        limit: 1,
      );
      if (existe.isNotEmpty) {
        continue;
      }
      final int id = await txn.insert('ambulances', {
        'immatriculation': b.immatriculation,
        'type': b.type,
        'statut': 'disponible',
        'latitude': b.lat,
        'longitude': b.lng,
        'kilometrage': b.km,
      });
      for (final List<String> e in b.equipage) {
        await txn.insert('ambulanciers', {
          'nom': e[0],
          'role': e[1],
          'telephone': e[2],
          'disponible': 1,
          'ambulance_id': id,
        });
      }
    }
  }

  // =====================================================================
  // Données de démonstration (région de Sousse / Monastir)
  // =====================================================================

  static const List<_Base> _ambulances = [
    _Base(1, '214 TU 5521', 'C', 35.8337, 10.5942, 84200),
    _Base(2, '198 TU 3307', 'B', 35.8290, 10.6335, 121450),
    _Base(3, '221 TU 1048', 'B', 35.8612, 10.5951, 59800),
    _Base(4, '187 TU 7712', 'A', 35.7642, 10.8110, 143900),
    _Base(5, '205 TU 2290', 'B', 35.8702, 10.5352, 99620),
    _Base(6, '176 TU 9083', 'A', 35.7290, 10.5800, 160350),
  ];

  static const List<_Lieu> _lieux = [
    _Lieu('Avenue Habib Bourguiba, Sousse', 35.8288, 10.6405, 5),
    _Lieu('Boujaafar, Sousse', 35.8335, 10.6395, 4),
    _Lieu('Khezama Est, Sousse', 35.8480, 10.6080, 4),
    _Lieu('Sahloul 4, Sousse', 35.8380, 10.5880, 3),
    _Lieu('Hammam Sousse', 35.8610, 10.5980, 3),
    _Lieu('Port El Kantaoui', 35.8930, 10.5960, 2),
    _Lieu('Akouda', 35.8690, 10.5670, 2),
    _Lieu('Kalâa Kebira', 35.8700, 10.5360, 2),
    _Lieu("M'saken", 35.7310, 10.5810, 2),
    _Lieu('Monastir centre', 35.7700, 10.8270, 3),
    _Lieu('Skanès, Monastir', 35.7590, 10.7720, 1),
    _Lieu('Ksar Hellal', 35.6440, 10.8920, 1),
  ];

  static Future<void> _donneesDemo(Transaction txn) async {
    final Batch b = txn.batch();
    final DateTime maintenant = DateTime.now();

    for (final _Base a in _ambulances) {
      b.insert('ambulances', {
        'id': a.id,
        'immatriculation': a.immatriculation,
        'type': a.type,
        'statut': 'disponible',
        'latitude': a.lat,
        'longitude': a.lng,
        'kilometrage': a.km,
      });
    }

    final List<List<Object?>> equipages = [
      [1, 'Ali Ben Amor', 'conducteur', '+21698123456', 1, 1],
      [2, 'Sana Mejri', 'infirmier', '+21697234567', 1, 1],
      [3, 'Amel Sfar', 'medecin', '+21622345678', 1, 1],
      [4, 'Hedi Kchaou', 'conducteur', '+21655456789', 1, 2],
      [5, 'Mouna Ayari', 'secouriste', '+21650567890', 1, 2],
      [6, 'Walid Chebbi', 'conducteur', '+21699678901', 1, 3],
      [7, 'Oussama Ferjani', 'secouriste', '+21620789012', 1, 3],
      [8, 'Nizar Belhaj', 'conducteur', '+21693890123', 1, 4],
      [9, 'Karim Dridi', 'conducteur', '+21658901234', 1, 5],
      [10, 'Fatma Hamdi', 'secouriste', '+21629012345', 0, null],
    ];
    for (final List<Object?> e in equipages) {
      b.insert('ambulanciers', {
        'id': e[0],
        'nom': e[1],
        'role': e[2],
        'telephone': e[3],
        'disponible': e[4],
        'ambulance_id': e[5],
      });
    }

    // Historique d'entretien : la n°5 approche de son seuil, la n°6 l'a
    // dépassé (elle sera bloquée automatiquement au premier contrôle).
    final List<List<Object?>> maintenances = [
      [1, 'revision', 40, 850.0, 100000, 'terminee'],
      [2, 'vidange', 20, 180.0, 130000, 'terminee'],
      [3, 'freins', 60, 420.0, 80000, 'terminee'],
      [4, 'revision', 90, 900.0, 150000, 'terminee'],
      [5, 'vidange', 100, 170.0, 100000, 'terminee'],
      [6, 'revision', 200, 780.0, 160000, 'terminee'],
      [3, 'equipement', -5, 300.0, null, 'planifiee'],
      [4, 'vidange', -2, 190.0, null, 'planifiee'],
    ];
    for (final List<Object?> m in maintenances) {
      final DateTime date = maintenant.subtract(Duration(days: m[2] as int));
      b.insert('maintenances', {
        'ambulance_id': m[0],
        'type': m[1],
        'date': date.toIso8601String().substring(0, 10),
        'cout': m[3],
        'prochain_entretien_km': m[4],
        'statut': m[5],
      });
    }

    await b.commit(noResult: true);

    await _historiqueInterventions(txn, maintenant);
    await _compteAmbulancier(txn);
  }

  /// 42 interventions passées sur 30 jours : alimentent les KPI et la heatmap.
  static Future<void> _historiqueInterventions(
    Transaction txn,
    DateTime maintenant,
  ) async {
    final math.Random r = math.Random(2026);

    final List<Map<String, Object?>> patients =
        await txn.query('patients', columns: ['id']);
    final List<int?> patientIds = [null, null];
    for (final Map<String, Object?> p in patients) {
      patientIds.add(p['id'] as int);
    }

    int poidsTotal = 0;
    for (final _Lieu l in _lieux) {
      poidsTotal += l.poids;
    }

    final Batch b = txn.batch();
    for (int i = 0; i < 42; i++) {
      // Lieu pondéré + petit décalage aléatoire (± 400 m)
      int tirage = r.nextInt(poidsTotal);
      _Lieu lieu = _lieux.first;
      for (final _Lieu l in _lieux) {
        if (tirage < l.poids) {
          lieu = l;
          break;
        }
        tirage -= l.poids;
      }
      final double lat = lieu.lat + (r.nextDouble() - 0.5) * 0.008;
      final double lng = lieu.lng + (r.nextDouble() - 0.5) * 0.008;
      final LatLng point = LatLng(lat, lng);

      final int g = r.nextInt(100);
      Gravite gravite = Gravite.faible;
      if (g < 15) {
        gravite = Gravite.critique;
      } else if (g < 50) {
        gravite = Gravite.urgente;
      } else if (g < 85) {
        gravite = Gravite.moderee;
      }

      // Ambulance la plus proche parmi les 5 qui étaient en service
      _Base amb = _ambulances.first;
      double min = double.infinity;
      for (int k = 0; k < 5; k++) {
        final _Base candidate = _ambulances[k];
        final double d =
            FormuleHaversine.distanceKm(point, LatLng(candidate.lat, candidate.lng));
        if (d < min) {
          min = d;
          amb = candidate;
        }
      }

      final DateTime appel = DateTime(
        maintenant.year,
        maintenant.month,
        maintenant.day,
        7 + r.nextInt(16),
        r.nextInt(60),
      ).subtract(Duration(days: 1 + r.nextInt(30)));
      final DateTime depart = appel.add(Duration(seconds: 60 + r.nextInt(180)));
      final Duration trajet = FormuleHaversine.dureeEstimee(min);
      final DateTime arrivee = depart.add(
        Duration(seconds: math.max(150, trajet.inSeconds) + r.nextInt(120)),
      );
      final bool annulee = i % 17 == 5;

      final int o = r.nextInt(10);
      String origine = 'appel';
      if (o >= 9) {
        origine = 'alerte';
      } else if (o >= 7) {
        origine = 'sos';
      }

      b.insert('interventions', {
        'ambulance_id': amb.id,
        'patient_id': patientIds[r.nextInt(patientIds.length)],
        'adresse': lieu.adresse,
        'lat': lat,
        'lng': lng,
        'gravite': gravite.code,
        'statut': annulee ? 'annulee' : 'terminee',
        'origine': origine,
        'heure_appel': appel.toIso8601String(),
        'heure_depart': depart.toIso8601String(),
        'heure_arrivee': annulee ? null : arrivee.toIso8601String(),
        'hopital_destination': annulee ? null : Hopitaux.plusProche(point).nom,
      });
    }
    await b.commit(noResult: true);
  }

  /// Compte de démo pour se connecter en tant qu'ambulancier (Ali Ben Amor).
  static Future<void> _compteAmbulancier(Transaction txn) async {
    await txn.insert(
      'utilisateurs',
      {
        'email': 'ambulancier@vitalwatch.tn',
        'mot_de_passe_hash': PasswordHasher.hacher('ambulancier123'),
        'role': Role.ambulancier.name,
        'ref_id': 1,
        'nom': 'Ben Amor',
        'prenom': 'Ali',
        'actif': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}

class _Base {
  const _Base(this.id, this.immatriculation, this.type, this.lat, this.lng, this.km);

  final int id;
  final String immatriculation;
  final String type;
  final double lat;
  final double lng;
  final int km;
}

class _BaseNationale {
  const _BaseNationale(
    this.immatriculation,
    this.type,
    this.lat,
    this.lng,
    this.km,
    this.base,
    this.equipage,
  );

  final String immatriculation;
  final String type;
  final double lat;
  final double lng;
  final int km;

  /// Nom de la base (documentation des données de démo).
  final String base;

  /// [nom, rôle, téléphone] des équipiers affectés à l'ambulance.
  final List<List<String>> equipage;
}

class _Lieu {
  const _Lieu(this.adresse, this.lat, this.lng, this.poids);

  final String adresse;
  final double lat;
  final double lng;
  final int poids;
}
