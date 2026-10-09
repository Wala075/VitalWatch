import 'package:sqflite/sqflite.dart';

import '../domain/authenticite_ordonnance.dart';
import '../domain/calcul_boites.dart';
import '../domain/dates_sql.dart';
import '../domain/models/apci.dart';
import '../domain/models/assurance.dart';
import '../domain/models/contrat_assurance.dart';
import '../domain/models/ligne_ordonnance.dart';
import '../domain/models/medicament.dart';
import '../domain/models/ordonnance.dart';
import '../domain/models/prise.dart';
import '../domain/models/taux_couverture.dart';
import '../domain/planning_prises.dart';
import 'numerotation.dart';

/// Données de démonstration du module 5, insérées une seule fois
/// (quand le catalogue est vide).
///
/// Prix, taux et plafonds : valeurs d'illustration, modifiables depuis
/// l'espace admin (jamais écrites ailleurs dans le code).
///
/// Comptes utiles pour la démo (base de app_database.dart) :
/// - Dr Amine Ben Salah (medecin@vitalwatch.tn) → patiente Sarra Trabelsi :
///   ORD-xxxx-0001, délivrée il y a 3 jours, prises en cours ;
/// - Dr Leila Gharbi (leila.gharbi@vitalwatch.tn) → patient Youssef Hammami
///   (APCI diabète) : ORD-xxxx-0002, validée aujourd'hui, à délivrer
///   par le pharmacien.
class PrescriptionsDemo {
  PrescriptionsDemo._();

  // Code-barres EAN-13 fictifs (préfixe tunisien 619).
  static const List<Medicament> medicaments = [
    // Paires princeps / générique (même DCI, dosage et forme) : substitution.
    Medicament(
      nomCommercial: 'Doliprane',
      dci: 'paracétamol',
      classe: 'antalgique',
      forme: 'comprimé',
      dosage: '1000 mg',
      unitesParBoite: 8,
      doseMaxJour: 4,
      codeBarres: '6199000000012',
      prixPublic: 2.4,
      prixReference: 1.6,
      categorie: CategorieMedicament.intermediaire,
    ),
    Medicament(
      nomCommercial: 'Paracétamol Générique',
      dci: 'paracétamol',
      classe: 'antalgique',
      forme: 'comprimé',
      dosage: '1000 mg',
      unitesParBoite: 8,
      doseMaxJour: 4,
      codeBarres: '6199000000029',
      prixPublic: 1.6,
      prixReference: 1.6,
      categorie: CategorieMedicament.intermediaire,
      generique: true,
    ),
    Medicament(
      nomCommercial: 'Glucophage',
      dci: 'metformine',
      classe: 'biguanide',
      forme: 'comprimé',
      dosage: '850 mg',
      unitesParBoite: 30,
      doseMaxJour: 3,
      codeBarres: '6199000000036',
      prixPublic: 6.5,
      prixReference: 4.2,
      categorie: CategorieMedicament.vital,
    ),
    Medicament(
      nomCommercial: 'Metformine Générique',
      dci: 'metformine',
      classe: 'biguanide',
      forme: 'comprimé',
      dosage: '850 mg',
      unitesParBoite: 30,
      doseMaxJour: 3,
      codeBarres: '6199000000043',
      prixPublic: 4.2,
      prixReference: 4.2,
      categorie: CategorieMedicament.vital,
      generique: true,
    ),
    Medicament(
      nomCommercial: 'Tahor',
      dci: 'atorvastatine',
      classe: 'statine',
      forme: 'comprimé',
      dosage: '20 mg',
      unitesParBoite: 30,
      doseMaxJour: 4,
      codeBarres: '6199000000050',
      prixPublic: 32.0,
      prixReference: 18.5,
      categorie: CategorieMedicament.essentiel,
    ),
    Medicament(
      nomCommercial: 'Atorvastatine Générique',
      dci: 'atorvastatine',
      classe: 'statine',
      forme: 'comprimé',
      dosage: '20 mg',
      unitesParBoite: 30,
      doseMaxJour: 4,
      codeBarres: '6199000000067',
      prixPublic: 18.5,
      prixReference: 18.5,
      categorie: CategorieMedicament.essentiel,
      generique: true,
    ),
    // L'exemple du cahier des charges : princeps 12,500 DT / générique 9,000 DT.
    Medicament(
      nomCommercial: 'Amlor',
      dci: 'amlodipine',
      classe: 'inhibiteur calcique',
      forme: 'gélule',
      dosage: '5 mg',
      unitesParBoite: 30,
      doseMaxJour: 2,
      codeBarres: '6199000000074',
      prixPublic: 12.5,
      prixReference: 9.0,
      categorie: CategorieMedicament.essentiel,
    ),
    Medicament(
      nomCommercial: 'Amlodipine Générique',
      dci: 'amlodipine',
      classe: 'inhibiteur calcique',
      forme: 'gélule',
      dosage: '5 mg',
      unitesParBoite: 30,
      doseMaxJour: 2,
      codeBarres: '6199000000081',
      prixPublic: 9.0,
      prixReference: 9.0,
      categorie: CategorieMedicament.essentiel,
      generique: true,
    ),
    Medicament(
      nomCommercial: 'Clamoxyl',
      dci: 'amoxicilline',
      classe: 'pénicilline',
      forme: 'comprimé',
      dosage: '1 g',
      unitesParBoite: 12,
      doseMaxJour: 3,
      codeBarres: '6199000000098',
      prixPublic: 9.8,
      prixReference: 7.2,
      categorie: CategorieMedicament.essentiel,
    ),
    Medicament(
      nomCommercial: 'Amoxicilline Générique',
      dci: 'amoxicilline',
      classe: 'pénicilline',
      forme: 'comprimé',
      dosage: '1 g',
      unitesParBoite: 12,
      doseMaxJour: 3,
      codeBarres: '6199000000104',
      prixPublic: 7.2,
      prixReference: 7.2,
      categorie: CategorieMedicament.essentiel,
      generique: true,
    ),
    Medicament(
      nomCommercial: 'Mopral',
      dci: 'oméprazole',
      classe: 'inhibiteur de la pompe à protons',
      forme: 'gélule',
      dosage: '20 mg',
      unitesParBoite: 14,
      doseMaxJour: 2,
      codeBarres: '6199000000111',
      prixPublic: 14.3,
      prixReference: 8.9,
      categorie: CategorieMedicament.intermediaire,
    ),
    Medicament(
      nomCommercial: 'Oméprazole Générique',
      dci: 'oméprazole',
      classe: 'inhibiteur de la pompe à protons',
      forme: 'gélule',
      dosage: '20 mg',
      unitesParBoite: 14,
      doseMaxJour: 2,
      codeBarres: '6199000000128',
      prixPublic: 8.9,
      prixReference: 8.9,
      categorie: CategorieMedicament.intermediaire,
      generique: true,
    ),
    // Médicaments seuls.
    Medicament(
      nomCommercial: 'Plavix',
      dci: 'clopidogrel',
      classe: 'antiagrégant plaquettaire',
      forme: 'comprimé',
      dosage: '75 mg',
      unitesParBoite: 28,
      doseMaxJour: 1,
      codeBarres: '6199000000135',
      prixPublic: 38.6,
      categorie: CategorieMedicament.essentiel,
    ),
    Medicament(
      nomCommercial: 'Lévothyrox',
      dci: 'lévothyroxine',
      classe: 'hormone thyroïdienne',
      forme: 'comprimé',
      dosage: '100 µg',
      unitesParBoite: 30,
      doseMaxJour: 3,
      codeBarres: '6199000000142',
      prixPublic: 3.9,
      categorie: CategorieMedicament.vital,
    ),
    Medicament(
      nomCommercial: 'Ventoline',
      dci: 'salbutamol',
      classe: 'bronchodilatateur',
      forme: 'aérosol doseur',
      dosage: '100 µg/dose',
      unitesParBoite: 200,
      doseMaxJour: 8,
      codeBarres: '6199000000159',
      prixPublic: 7.8,
      categorie: CategorieMedicament.vital,
    ),
    Medicament(
      nomCommercial: 'Lantus',
      dci: 'insuline glargine',
      classe: 'insuline',
      forme: 'stylo injectable',
      dosage: '100 UI/ml',
      unitesParBoite: 1500,
      doseMaxJour: 80,
      codeBarres: '6199000000166',
      prixPublic: 98.0,
      categorie: CategorieMedicament.vital,
    ),
    Medicament(
      nomCommercial: 'Brufen',
      dci: 'ibuprofène',
      classe: 'anti-inflammatoire',
      forme: 'comprimé',
      dosage: '400 mg',
      unitesParBoite: 30,
      doseMaxJour: 3,
      codeBarres: '6199000000173',
      prixPublic: 5.6,
      categorie: CategorieMedicament.intermediaire,
    ),
    Medicament(
      nomCommercial: 'Aspégic',
      dci: 'acide acétylsalicylique',
      classe: 'antiagrégant plaquettaire',
      forme: 'sachet',
      dosage: '100 mg',
      unitesParBoite: 30,
      doseMaxJour: 3,
      codeBarres: '6199000000180',
      prixPublic: 4.1,
      categorie: CategorieMedicament.essentiel,
    ),
    Medicament(
      nomCommercial: 'Zithromax',
      dci: 'azithromycine',
      classe: 'macrolide',
      forme: 'comprimé',
      dosage: '250 mg',
      unitesParBoite: 6,
      doseMaxJour: 2,
      codeBarres: '6199000000197',
      prixPublic: 15.9,
      categorie: CategorieMedicament.essentiel,
    ),
    // Sirop : unités en ml (10 ml par prise).
    Medicament(
      nomCommercial: 'Toplexil',
      dci: 'oxomémazine',
      classe: 'antitussif',
      forme: 'sirop',
      dosage: '0,33 mg/ml',
      unitesParBoite: 150,
      doseMaxJour: 40,
      codeBarres: '6199000000203',
      prixPublic: 4.9,
      categorie: CategorieMedicament.nonRemboursable,
    ),
    Medicament(
      nomCommercial: 'Magné B6',
      dci: 'magnésium + vitamine B6',
      classe: 'complément minéral',
      forme: 'comprimé',
      dosage: '48 mg',
      unitesParBoite: 50,
      doseMaxJour: 6,
      codeBarres: '6199000000210',
      prixPublic: 8.2,
      categorie: CategorieMedicament.nonRemboursable,
    ),
  ];

  /// Taux CNAM d'illustration par catégorie.
  static const Map<CategorieMedicament, double> tauxCnam = {
    CategorieMedicament.vital: 1.0,
    CategorieMedicament.essentiel: 0.85,
    CategorieMedicament.intermediaire: 0.40,
    CategorieMedicament.nonRemboursable: 0.0,
  };

  static const List<Apci> apci = [
    Apci(codeCim10: 'B18', libelle: 'Hépatite virale chronique'),
    Apci(codeCim10: 'C50', libelle: 'Cancer du sein'),
    Apci(codeCim10: 'E10', libelle: 'Diabète de type 1'),
    Apci(codeCim10: 'E11', libelle: 'Diabète de type 2'),
    Apci(codeCim10: 'G20', libelle: 'Maladie de Parkinson'),
    Apci(codeCim10: 'G40', libelle: 'Épilepsie'),
    Apci(codeCim10: 'I10', libelle: 'Hypertension artérielle sévère'),
    Apci(codeCim10: 'I25', libelle: 'Cardiopathie ischémique chronique'),
    Apci(codeCim10: 'I50', libelle: 'Insuffisance cardiaque'),
    Apci(codeCim10: 'J45', libelle: 'Asthme sévère'),
    Apci(codeCim10: 'M05', libelle: 'Polyarthrite rhumatoïde'),
    Apci(codeCim10: 'N18', libelle: 'Insuffisance rénale chronique'),
  ];

  static Future<void> inserer(Transaction txn) async {
    // ----- Catalogue -----
    final Map<String, int> ids = {};
    for (final Medicament m in medicaments) {
      ids[m.nomCommercial] = await txn.insert('medicament', m.toMap());
    }

    // ----- Assurances et taux -----
    final int cnam = await txn.insert(
      'assurance',
      const Assurance(
        nom: 'CNAM',
        type: TypeAssurance.cnam,
        plafondAnnuel: 600,
        delaiReponseJours: 30,
      ).toMap(),
    );
    for (final CategorieMedicament c in tauxCnam.keys) {
      await txn.insert(
        'taux_couverture',
        TauxCouverture(assuranceId: cnam, categorie: c.valeur, taux: tauxCnam[c]!).toMap(),
      );
    }

    final int mutuelle = await txn.insert(
      'assurance',
      const Assurance(
        nom: 'Mutuelle VitalSanté',
        type: TypeAssurance.mutuelle,
        plafondAnnuel: 1000,
        delaiReponseJours: 15,
      ).toMap(),
    );
    await txn.insert(
      'taux_couverture',
      TauxCouverture(assuranceId: mutuelle, categorie: TauxCouverture.tous, taux: 0.80).toMap(),
    );

    // ----- Référentiel APCI -----
    for (final Apci a in apci) {
      await txn.insert('apci', a.toMap());
    }

    // ----- Contrats des patients de démo -----
    if (await _existe(txn, 'patients', 1)) {
      // Sarra Trabelsi : CNAM + mutuelle.
      await txn.insert(
        'contrat_assurance',
        ContratAssurance(
          patientId: 1,
          assuranceId: cnam,
          numeroAdherent: '12345678',
          filiere: FiliereCnam.remboursement,
          dateDebut: DateTime(2024, 1, 1),
        ).toMap(),
      );
      await txn.insert(
        'contrat_assurance',
        ContratAssurance(
          patientId: 1,
          assuranceId: mutuelle,
          numeroAdherent: '50012345',
          dateDebut: DateTime(2025, 1, 1),
        ).toMap(),
      );
    }
    if (await _existe(txn, 'patients', 2)) {
      // Youssef Hammami : CNAM en APCI (diabète de type 2).
      await txn.insert(
        'contrat_assurance',
        ContratAssurance(
          patientId: 2,
          assuranceId: cnam,
          numeroAdherent: '23456789',
          filiere: FiliereCnam.publique,
          dateDebut: DateTime(2023, 1, 1),
          apci: true,
          codeApci: 'E11',
        ).toMap(),
      );
    }
    if (await _existe(txn, 'patients', 3)) {
      // Ines Kefi (enfant) : ayant droit sur le contrat CNAM d'un parent.
      await txn.insert(
        'contrat_assurance',
        ContratAssurance(
          patientId: 3,
          assuranceId: cnam,
          numeroAdherent: '34567890',
          filiere: FiliereCnam.publique,
          beneficiaire: Beneficiaire.enfant,
          dateDebut: DateTime(2018, 3, 20),
        ).toMap(),
      );
    }

    // ----- Ordonnances exemples -----
    final DateTime maintenant = DateTime.now();
    final DateTime aujourdhui = DatesSql.jour(maintenant);

    if (await _existe(txn, 'patients', 1) && await _existe(txn, 'medecins', 1)) {
      final DateTime emission = aujourdhui.subtract(const Duration(days: 3));
      await _ordonnance(
        txn,
        ids: ids,
        patientId: 1,
        medecinId: 1,
        emission: emission,
        debutPlanning: emission,
        maintenant: maintenant,
        nbRenouvellements: 0,
        delivree: true,
        lignes: const [
          _Ligne('Amlor', ['matin'], 30, instructions: 'Le matin, au petit-déjeuner'),
          _Ligne('Doliprane', ['matin', 'midi', 'soir'], 5, instructions: 'Pendant les repas'),
        ],
      );
    }

    if (await _existe(txn, 'patients', 2) && await _existe(txn, 'medecins', 2)) {
      await _ordonnance(
        txn,
        ids: ids,
        patientId: 2,
        medecinId: 2,
        emission: aujourdhui,
        debutPlanning: maintenant,
        maintenant: maintenant,
        nbRenouvellements: 2,
        delivree: false,
        lignes: const [
          _Ligne('Glucophage', ['matin', 'soir'], 30, apci: true, instructions: 'Au milieu des repas'),
          _Ligne('Tahor', ['soir'], 30, instructions: 'Le soir'),
        ],
      );
    }
  }

  /// Crée une ordonnance comme le ferait le médecin : brouillon, lignes,
  /// validation (signature + planning), puis délivrance éventuelle.
  static Future<void> _ordonnance(
    Transaction txn, {
    required Map<String, int> ids,
    required int patientId,
    required int medecinId,
    required DateTime emission,
    required DateTime debutPlanning,
    required DateTime maintenant,
    required int nbRenouvellements,
    required bool delivree,
    required List<_Ligne> lignes,
  }) async {
    final Ordonnance brouillon = Ordonnance(
      numero: await Numerotation.prochain(
        txn,
        table: 'ordonnance',
        prefixe: 'ORD',
        annee: emission.year,
      ),
      patientId: patientId,
      medecinId: medecinId,
      dateEmission: emission,
      dateExpiration: emission.add(const Duration(days: Ordonnance.validiteJoursParDefaut)),
      nbRenouvellements: nbRenouvellements,
    );
    final int id = await txn.insert('ordonnance', brouillon.toMap());

    final List<LigneOrdonnance> inserees = [];
    for (final _Ligne l in lignes) {
      final Medicament m = _parNom(l.medicament);
      final LigneOrdonnance ligne = LigneOrdonnance(
        ordonnanceId: id,
        medicamentId: ids[l.medicament]!,
        dosePrise: l.dose,
        prisesParJour: l.moments.length,
        moments: l.moments,
        dureeJours: l.dureeJours,
        quantiteBoites: CalculBoites.calculer(
          dosePrise: l.dose,
          prisesParJour: l.moments.length,
          dureeJours: l.dureeJours,
          unitesParBoite: m.unitesParBoite,
        ),
        lienApci: l.apci,
        instructions: l.instructions,
      );
      final int ligneId = await txn.insert('ligne_ordonnance', ligne.toMap());
      inserees.add(ligne.copyWith(id: ligneId));
    }

    // Validation : signature SHA-256 puis planning des prises.
    await txn.update(
      'ordonnance',
      {
        'statut': StatutOrdonnance.validee.valeur,
        'hash_signature': AuthenticiteOrdonnance.signer(brouillon, inserees),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    final Batch b = txn.batch();
    for (final LigneOrdonnance l in inserees) {
      final List<Prise> prises = PlanningPrises.generer(
        ligneId: l.id!,
        momentsLigne: l.moments,
        dureeJours: l.dureeJours,
        debut: debutPlanning,
      );
      for (int i = 0; i < prises.length; i++) {
        b.insert('prise', _historique(prises[i], i, maintenant).toMap());
      }
    }
    await b.commit(noResult: true);

    if (delivree) {
      for (final LigneOrdonnance l in inserees) {
        await txn.update(
          'ligne_ordonnance',
          {'quantite_delivree': l.quantiteBoites},
          where: 'id = ?',
          whereArgs: [l.id],
        );
      }
      await txn.update(
        'ordonnance',
        {'statut': StatutOrdonnance.delivree.valeur},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Prises passées depuis plus de 3 h : faites, sauf une sur cinq oubliée
  /// (pour avoir une observance réaliste dès l'installation).
  static Prise _historique(Prise p, int rang, DateTime maintenant) {
    if (p.heurePrevue.isAfter(maintenant.subtract(const Duration(hours: 3)))) {
      return p;
    }
    if (rang % 5 == 3) {
      return Prise(ligneId: p.ligneId, heurePrevue: p.heurePrevue, statut: StatutPrise.oubliee);
    }
    return Prise(
      ligneId: p.ligneId,
      heurePrevue: p.heurePrevue,
      heureReelle: p.heurePrevue.add(Duration(minutes: 5 + rang % 20)),
      statut: StatutPrise.prise,
    );
  }

  static Medicament _parNom(String nom) {
    for (final Medicament m in medicaments) {
      if (m.nomCommercial == nom) {
        return m;
      }
    }
    throw StateError('Médicament de démo inconnu : $nom');
  }

  static Future<bool> _existe(Transaction txn, String table, int id) async {
    final List<Map<String, Object?>> rows = await txn.query(
      table,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}

/// Ligne d'ordonnance de démo (posologie en unités du médicament).
class _Ligne {
  const _Ligne(
    this.medicament,
    this.moments,
    this.dureeJours, {
    this.dose = 1,
    this.apci = false,
    this.instructions,
  });

  /// Nom commercial dans [PrescriptionsDemo.medicaments].
  final String medicament;
  final List<String> moments;
  final int dureeJours;
  final double dose;
  final bool apci;
  final String? instructions;
}
