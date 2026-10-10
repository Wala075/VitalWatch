import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/services/app_database.dart';
import '../../../core/utils/password_hasher.dart';
import '../../../models/utilisateur.dart';
import '../domain/dates_sql.dart';
import 'prescriptions_demo.dart';

/// Tables du module 5 (Ordonnances & Assurance).
///
/// Créées ici avec « IF NOT EXISTS » au premier accès, comme le module 3 :
/// app_database.dart (fichier commun) n'est pas modifié.
///
/// Tables des autres gestions seulement référencées : patients, medecins.
/// La table consultation (Rendez-vous) n'existe pas encore :
/// consultation_id n'a donc pas de clé étrangère pour l'instant.
class PrescriptionsSchema {
  PrescriptionsSchema._();

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

  /// Appelé une fois dans main() : crée les tables, ajoute le compte
  /// pharmacien de démo et passe les ordonnances périmées en « expirée ».
  /// Une erreur ici n'empêche jamais l'application de démarrer.
  static Future<void> initialiserAuDemarrage() async {
    try {
      await database;
    } catch (e, pile) {
      debugPrint('Module Ordonnances : initialisation impossible : $e');
      debugPrintStack(stackTrace: pile);
    }
  }

  /// Métier 1 : expiration automatique, exécutée au démarrage de l'app.
  /// Paramètre : la date du jour (DatesSql.date).
  static const String sqlExpiration = '''
    UPDATE ordonnance SET statut = 'expiree'
    WHERE statut IN ('validee', 'partiellement_delivree')
      AND date_expiration < ?
  ''';

  static Future<void> _initialiser(Database db) async {
    await db.transaction((Transaction txn) async {
      for (final String sql in tables) {
        await txn.execute(sql);
      }
      await _ajouterColonneStock(txn);
      for (final String sql in index) {
        await txn.execute(sql);
      }
      for (final String sql in declencheurs) {
        await txn.execute(sql);
      }

      await _comptePharmacien(txn);

      // Données de démo une seule fois : catalogue et assurances vides.
      final int nb = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT (SELECT COUNT(*) FROM medicament) + (SELECT COUNT(*) FROM assurance)',
            ),
          ) ??
          0;
      if (nb == 0) {
        await PrescriptionsDemo.inserer(txn);
      }

      // Historique de démo (dossiers, statistiques) : une seule fois,
      // y compris sur une base déjà remplie avant cette version.
      if (await _lireMeta(txn, 'demo_historique') == null) {
        await PrescriptionsDemo.historique(txn);
        await txn.insert(
          'prescriptions_meta',
          {'cle': 'demo_historique', 'valeur': DatesSql.date(DateTime.now())},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Stock de démo et médicaments couverts par les APCI : une seule fois.
      if (await _lireMeta(txn, 'demo_stock_apci') == null) {
        await PrescriptionsDemo.stockEtApci(txn);
        await txn.insert(
          'prescriptions_meta',
          {'cle': 'demo_stock_apci', 'valeur': DatesSql.date(DateTime.now())},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.rawUpdate(sqlExpiration, [DatesSql.date(DateTime.now())]);
    });
  }

  /// Base créée avant l'ajout du stock : la colonne est ajoutée une fois.
  static Future<void> _ajouterColonneStock(Transaction txn) async {
    final List<Map<String, Object?>> colonnes = await txn.rawQuery('PRAGMA table_info(medicament)');
    for (final Map<String, Object?> c in colonnes) {
      if (c['name'] == 'stock') {
        return;
      }
    }
    await txn.execute(
      'ALTER TABLE medicament ADD COLUMN stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0)',
    );
  }

  static Future<String?> _lireMeta(Transaction txn, String cle) async {
    final List<Map<String, Object?>> rows = await txn.query(
      'prescriptions_meta',
      columns: ['valeur'],
      where: 'cle = ?',
      whereArgs: [cle],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['valeur'] as String?;
  }

  /// Compte de démo du pharmacien (délivrance des ordonnances).
  static Future<void> _comptePharmacien(Transaction txn) async {
    await txn.insert(
      'utilisateurs',
      {
        'email': 'pharmacien@vitalwatch.tn',
        'mot_de_passe_hash': PasswordHasher.hacher('pharmacien123'),
        'role': Role.pharmacien.name,
        'ref_id': null,
        'nom': 'Mejri',
        'prenom': 'Hela',
        'actif': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // =====================================================================
  // Tables
  // =====================================================================

  static const List<String> tables = [
    // Catalogue des médicaments.
    '''
    CREATE TABLE IF NOT EXISTS medicament (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      nom_commercial   TEXT NOT NULL,
      dci              TEXT NOT NULL,
      rxcui            TEXT,
      classe           TEXT,
      forme            TEXT NOT NULL,
      dosage           TEXT NOT NULL,
      unites_par_boite INTEGER NOT NULL CHECK (unites_par_boite > 0),
      dose_max_jour    REAL,
      code_barres      TEXT UNIQUE,
      prix_public      REAL NOT NULL CHECK (prix_public >= 0),
      prix_reference   REAL CHECK (prix_reference >= 0),
      categorie        TEXT NOT NULL
                       CHECK (categorie IN ('vital', 'essentiel', 'intermediaire', 'non_remboursable')),
      generique        INTEGER NOT NULL DEFAULT 0,
      actif            INTEGER NOT NULL DEFAULT 1,
      stock            INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0)
    )
    ''',

    // Document daté du médecin.
    '''
    CREATE TABLE IF NOT EXISTS ordonnance (
      id                    INTEGER PRIMARY KEY AUTOINCREMENT,
      numero                TEXT NOT NULL UNIQUE,
      patient_id            INTEGER NOT NULL REFERENCES patients(id) ON DELETE RESTRICT,
      medecin_id            INTEGER NOT NULL REFERENCES medecins(id),
      consultation_id       INTEGER,
      date_emission         TEXT NOT NULL,
      date_expiration       TEXT NOT NULL,
      statut                TEXT NOT NULL DEFAULT 'brouillon'
                            CHECK (statut IN ('brouillon', 'validee', 'partiellement_delivree',
                                              'delivree', 'expiree', 'annulee')),
      nb_renouvellements    INTEGER NOT NULL DEFAULT 0 CHECK (nb_renouvellements BETWEEN 0 AND 6),
      ordonnance_origine_id INTEGER REFERENCES ordonnance(id),
      hash_signature        TEXT,
      motif_annulation      TEXT,
      CHECK (date_expiration > date_emission),
      CHECK (statut <> 'annulee' OR motif_annulation IS NOT NULL)
    )
    ''',

    // Un médicament de l'ordonnance, sa posologie et sa durée.
    '''
    CREATE TABLE IF NOT EXISTS ligne_ordonnance (
      id                     INTEGER PRIMARY KEY AUTOINCREMENT,
      ordonnance_id          INTEGER NOT NULL REFERENCES ordonnance(id) ON DELETE CASCADE,
      medicament_id          INTEGER NOT NULL REFERENCES medicament(id),
      dose_par_prise         REAL NOT NULL CHECK (dose_par_prise > 0),
      prises_par_jour        INTEGER NOT NULL CHECK (prises_par_jour BETWEEN 1 AND 6),
      moments                TEXT NOT NULL,
      duree_jours            INTEGER NOT NULL CHECK (duree_jours BETWEEN 1 AND 365),
      quantite_boites        INTEGER NOT NULL CHECK (quantite_boites > 0),
      quantite_delivree      INTEGER NOT NULL DEFAULT 0,
      substitution_autorisee INTEGER NOT NULL DEFAULT 1,
      lien_apci              INTEGER NOT NULL DEFAULT 0,
      instructions           TEXT,
      UNIQUE (ordonnance_id, medicament_id),
      CHECK (quantite_delivree <= quantite_boites)
    )
    ''',

    // Une prise prévue et son suivi.
    '''
    CREATE TABLE IF NOT EXISTS prise (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      ligne_id    INTEGER NOT NULL REFERENCES ligne_ordonnance(id) ON DELETE CASCADE,
      heure_prevue TEXT NOT NULL,
      heure_reelle TEXT,
      statut      TEXT NOT NULL DEFAULT 'prevue' CHECK (statut IN ('prevue', 'prise', 'oubliee'))
    )
    ''',

    // Organisme : CNAM, mutuelle ou assurance privée.
    '''
    CREATE TABLE IF NOT EXISTS assurance (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      nom                 TEXT NOT NULL UNIQUE,
      type                TEXT NOT NULL CHECK (type IN ('cnam', 'mutuelle', 'privee')),
      plafond_annuel      REAL,
      delai_reponse_jours INTEGER NOT NULL DEFAULT 30
    )
    ''',

    // Taux de prise en charge par catégorie de médicament ('tous' pour une mutuelle).
    '''
    CREATE TABLE IF NOT EXISTS taux_couverture (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      assurance_id INTEGER NOT NULL REFERENCES assurance(id) ON DELETE CASCADE,
      categorie   TEXT NOT NULL,
      taux        REAL NOT NULL CHECK (taux BETWEEN 0 AND 1),
      UNIQUE (assurance_id, categorie)
    )
    ''',

    // Référentiel : code CIM-10 → maladie prise en charge à 100 %.
    '''
    CREATE TABLE IF NOT EXISTS apci (
      code_cim10 TEXT PRIMARY KEY,
      libelle    TEXT NOT NULL
    )
    ''',

    // Médicaments couverts par une APCI (par DCI : le princeps et ses
    // génériques), tenus par le pharmacien et contrôlés à la délivrance.
    '''
    CREATE TABLE IF NOT EXISTS apci_medicament (
      code_apci TEXT NOT NULL REFERENCES apci(code_cim10) ON DELETE CASCADE,
      dci       TEXT NOT NULL,
      PRIMARY KEY (code_apci, dci)
    )
    ''',

    // Couverture d'un patient par un organisme.
    '''
    CREATE TABLE IF NOT EXISTS contrat_assurance (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id      INTEGER NOT NULL REFERENCES patients(id) ON DELETE RESTRICT,
      assurance_id    INTEGER NOT NULL REFERENCES assurance(id),
      numero_adherent TEXT NOT NULL,
      filiere         TEXT CHECK (filiere IS NULL OR filiere IN ('publique', 'privee', 'remboursement')),
      beneficiaire    TEXT NOT NULL DEFAULT 'assure'
                      CHECK (beneficiaire IN ('assure', 'conjoint', 'enfant')),
      date_debut      TEXT NOT NULL,
      date_fin        TEXT,
      apci            INTEGER NOT NULL DEFAULT 0,
      code_apci       TEXT REFERENCES apci(code_cim10),
      UNIQUE (assurance_id, numero_adherent, beneficiaire),
      CHECK (date_fin IS NULL OR date_fin > date_debut),
      CHECK (apci = 0 OR code_apci IS NOT NULL)
    )
    ''',

    // Réglages internes du module (versions des données de démo).
    '''
    CREATE TABLE IF NOT EXISTS prescriptions_meta (
      cle    TEXT PRIMARY KEY,
      valeur TEXT
    )
    ''',

    // Demande de remboursement d'une ordonnance délivrée.
    // Le plafond consommé n'est pas stocké : il est recalculé (voir
    // DossierRemboursementRepository.plafondConsomme).
    '''
    CREATE TABLE IF NOT EXISTS dossier_remboursement (
      id                        INTEGER PRIMARY KEY AUTOINCREMENT,
      numero                    TEXT NOT NULL UNIQUE,
      ordonnance_id             INTEGER NOT NULL REFERENCES ordonnance(id),
      contrat_id                INTEGER NOT NULL REFERENCES contrat_assurance(id),
      contrat_complementaire_id INTEGER REFERENCES contrat_assurance(id),
      montant_total             REAL NOT NULL CHECK (montant_total >= 0),
      part_obligatoire          REAL NOT NULL DEFAULT 0,
      part_complementaire       REAL NOT NULL DEFAULT 0,
      reste_a_charge            REAL NOT NULL DEFAULT 0,
      statut                    TEXT NOT NULL DEFAULT 'brouillon'
                                CHECK (statut IN ('brouillon', 'soumis', 'en_cours', 'accepte',
                                                  'partiel', 'refuse', 'rembourse')),
      date_depot                TEXT,
      date_reponse              TEXT,
      motif_refus               TEXT,
      reste_paye                INTEGER NOT NULL DEFAULT 0,
      reference_paiement        TEXT,
      CHECK (part_obligatoire + part_complementaire <= montant_total + 0.001),
      CHECK (statut <> 'refuse' OR motif_refus IS NOT NULL)
    )
    ''',
  ];

  static const List<String> index = [
    'CREATE INDEX IF NOT EXISTS idx_prise ON prise(ligne_id, heure_prevue)',
    'CREATE INDEX IF NOT EXISTS idx_ordonnance_patient ON ordonnance(patient_id, date_emission)',
    'CREATE INDEX IF NOT EXISTS idx_ordonnance_statut ON ordonnance(statut)',
    'CREATE INDEX IF NOT EXISTS idx_ligne_ordonnance ON ligne_ordonnance(ordonnance_id)',
    'CREATE INDEX IF NOT EXISTS idx_contrat_patient ON contrat_assurance(patient_id)',
    'CREATE INDEX IF NOT EXISTS idx_dossier_ordonnance ON dossier_remboursement(ordonnance_id)',
  ];

  // =====================================================================
  // Déclencheurs : le verrouillage est respecté directement dans la base,
  // même si un écran oublie le contrôle. Ils ne bloquent que les vraies
  // modifications (NEW <> OLD) : réécrire la même valeur reste permis.
  // =====================================================================

  static const List<String> declencheurs = [
    // Cahier des charges : une ordonnance validée ne se supprime pas.
    '''
    CREATE TRIGGER IF NOT EXISTS trg_ordonnance_suppression
    BEFORE DELETE ON ordonnance
    WHEN OLD.statut <> 'brouillon'
    BEGIN
      SELECT RAISE(ABORT, 'Ordonnance validée : annulation uniquement');
    END
    ''',

    // Cahier des charges : les lignes d'une ordonnance validée ne changent plus
    // (seule la quantité délivrée avance).
    '''
    CREATE TRIGGER IF NOT EXISTS trg_ligne_verrou
    BEFORE UPDATE OF ordonnance_id, medicament_id, dose_par_prise, prises_par_jour, moments,
                     duree_jours, quantite_boites, substitution_autorisee, lien_apci, instructions
    ON ligne_ordonnance
    WHEN (SELECT statut FROM ordonnance WHERE id = OLD.ordonnance_id) <> 'brouillon'
     AND (NEW.ordonnance_id IS NOT OLD.ordonnance_id
          OR NEW.medicament_id IS NOT OLD.medicament_id
          OR NEW.dose_par_prise IS NOT OLD.dose_par_prise
          OR NEW.prises_par_jour IS NOT OLD.prises_par_jour
          OR NEW.moments IS NOT OLD.moments
          OR NEW.duree_jours IS NOT OLD.duree_jours
          OR NEW.quantite_boites IS NOT OLD.quantite_boites
          OR NEW.substitution_autorisee IS NOT OLD.substitution_autorisee
          OR NEW.lien_apci IS NOT OLD.lien_apci
          OR NEW.instructions IS NOT OLD.instructions)
    BEGIN
      SELECT RAISE(ABORT, 'Ordonnance verrouillée');
    END
    ''',

    // Pas d'ajout de ligne sur une ordonnance validée.
    '''
    CREATE TRIGGER IF NOT EXISTS trg_ligne_ajout_verrou
    BEFORE INSERT ON ligne_ordonnance
    WHEN (SELECT statut FROM ordonnance WHERE id = NEW.ordonnance_id) <> 'brouillon'
    BEGIN
      SELECT RAISE(ABORT, 'Ordonnance verrouillée');
    END
    ''',

    // Pas de suppression de ligne sur une ordonnance validée.
    '''
    CREATE TRIGGER IF NOT EXISTS trg_ligne_suppression_verrou
    BEFORE DELETE ON ligne_ordonnance
    WHEN (SELECT statut FROM ordonnance WHERE id = OLD.ordonnance_id) <> 'brouillon'
    BEGIN
      SELECT RAISE(ABORT, 'Ordonnance verrouillée');
    END
    ''',

    // L'en-tête d'une ordonnance validée ne change plus, et elle ne peut pas
    // redevenir un brouillon (sinon le verrou serait contournable).
    '''
    CREATE TRIGGER IF NOT EXISTS trg_ordonnance_verrou
    BEFORE UPDATE OF numero, patient_id, medecin_id, consultation_id, date_emission,
                     date_expiration, hash_signature, statut
    ON ordonnance
    WHEN OLD.statut <> 'brouillon'
     AND (NEW.statut = 'brouillon'
          OR NEW.numero IS NOT OLD.numero
          OR NEW.patient_id IS NOT OLD.patient_id
          OR NEW.medecin_id IS NOT OLD.medecin_id
          OR NEW.consultation_id IS NOT OLD.consultation_id
          OR NEW.date_emission IS NOT OLD.date_emission
          OR NEW.date_expiration IS NOT OLD.date_expiration
          OR NEW.hash_signature IS NOT OLD.hash_signature)
    BEGIN
      SELECT RAISE(ABORT, 'Ordonnance verrouillée');
    END
    ''',
  ];
}
