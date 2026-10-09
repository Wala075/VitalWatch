import 'package:sqflite/sqflite.dart';

import '../data/apci_repository.dart';
import '../data/assurance_repository.dart';
import '../data/medicament_repository.dart';
import '../data/prescriptions_schema.dart';
import '../data/taux_couverture_repository.dart';
import 'models/apci.dart';
import 'models/assurance.dart';
import 'models/medicament.dart';
import 'models/taux_couverture.dart';
import 'prescriptions_exception.dart';
import 'regles_referentiels.dart';
import 'saisie.dart';

/// Règles métier des référentiels gérés par l'admin :
/// catalogue des médicaments, assurances et taux, liste APCI.
class ReferentielsManager {
  ReferentielsManager({
    MedicamentRepository? medicaments,
    AssuranceRepository? assurances,
    TauxCouvertureRepository? taux,
    ApciRepository? apci,
  })  : _medicaments = medicaments ?? MedicamentRepository(),
        _assurances = assurances ?? AssuranceRepository(),
        _taux = taux ?? TauxCouvertureRepository(),
        _apci = apci ?? ApciRepository();

  final MedicamentRepository _medicaments;
  final AssuranceRepository _assurances;
  final TauxCouvertureRepository _taux;
  final ApciRepository _apci;

  // =====================================================================
  // Médicaments
  // =====================================================================

  Future<int> enregistrerMedicament(Medicament m) async {
    final String? erreur = ReglesReferentiels.medicament(m);
    if (erreur != null) {
      throw PrescriptionsException(erreur);
    }
    final String? code = m.codeBarres;
    if (code != null && await _medicaments.codeBarresExiste(code, exclureId: m.id)) {
      throw const PrescriptionsException('Ce code-barres est déjà utilisé par un autre médicament');
    }

    final int? id = m.id;
    if (id == null) {
      return _medicaments.inserer(m);
    }
    await _medicaments.modifier(m);
    return id;
  }

  /// Un médicament déjà prescrit est archivé (actif = 0) au lieu d'être
  /// supprimé. Renvoie true s'il a été archivé, false s'il a été supprimé.
  Future<bool> supprimerMedicament(int id) async {
    if (await _medicaments.estDejaPrescrit(id)) {
      await _medicaments.archiver(id);
      return true;
    }
    await _medicaments.supprimer(id);
    return false;
  }

  Future<void> reactiverMedicament(Medicament m) {
    return _medicaments.modifier(m.copyWith(actif: true));
  }

  // =====================================================================
  // Assurances et taux
  // =====================================================================

  /// Enregistre l'assurance et remplace tous ses taux (une seule transaction).
  Future<int> enregistrerAssurance(Assurance a, List<TauxCouverture> taux) async {
    final String? erreur = ReglesReferentiels.assurance(a, taux);
    if (erreur != null) {
      throw PrescriptionsException(erreur);
    }
    if (await _assurances.nomExiste(a.nom, exclureId: a.id)) {
      throw PrescriptionsException("L'assurance « ${a.nom.trim()} » existe déjà");
    }
    if (a.type == TypeAssurance.cnam && await _assurances.cnamExiste(exclureId: a.id)) {
      throw const PrescriptionsException('La CNAM existe déjà : une seule assurance obligatoire');
    }

    final Database db = await PrescriptionsSchema.database;
    return db.transaction((Transaction txn) async {
      int id;
      final int? existant = a.id;
      if (existant == null) {
        id = await _assurances.inserer(a, exec: txn);
      } else {
        id = existant;
        await _assurances.modifier(a, exec: txn);
      }
      await _taux.remplacer(id, taux, exec: txn);
      return id;
    });
  }

  /// Seulement si aucun contrat n'y est lié (ses taux partent en cascade).
  Future<void> supprimerAssurance(int id) async {
    final int nb = await _assurances.nombreContrats(id);
    if (nb > 0) {
      throw PrescriptionsException(
        'Suppression impossible : $nb contrat${nb > 1 ? 's' : ''} patient '
        '${nb > 1 ? 'sont liés' : 'est lié'} à cette assurance',
      );
    }
    await _assurances.supprimer(id);
  }

  // =====================================================================
  // Référentiel APCI
  // =====================================================================

  Future<void> ajouterApci(String code, String libelle) async {
    final String c = code.trim().toUpperCase();
    final String? erreur = Saisie.codeCim10(c) ?? Saisie.requis(libelle, champ: 'Le libellé');
    if (erreur != null) {
      throw PrescriptionsException(erreur);
    }
    if (await _apci.parCode(c) != null) {
      throw PrescriptionsException('Le code $c est déjà dans la liste APCI');
    }
    await _apci.inserer(Apci(codeCim10: c, libelle: libelle.trim()));
  }

  Future<void> modifierLibelleApci(String code, String libelle) async {
    final String? erreur = Saisie.requis(libelle, champ: 'Le libellé');
    if (erreur != null) {
      throw PrescriptionsException(erreur);
    }
    await _apci.modifierLibelle(code, libelle);
  }

  /// Seulement si aucun contrat ne la référence.
  Future<void> supprimerApci(String code) async {
    if (await _apci.estReferencee(code)) {
      throw PrescriptionsException(
        'Suppression impossible : un contrat APCI utilise le code $code',
      );
    }
    await _apci.supprimer(code);
  }
}
