import 'package:sqflite/sqflite.dart';

import '../../../core/utils/formatters.dart';
import '../data/ligne_ordonnance_repository.dart';
import '../data/ordonnance_repository.dart';
import '../data/prescriptions_schema.dart';
import 'authenticite_ordonnance.dart';
import 'dates_sql.dart';
import 'models/ligne_ordonnance.dart';
import 'models/ordonnance.dart';
import 'models/vues_ordonnance.dart';
import 'ordonnance_manager.dart';
import 'prescriptions_exception.dart';

/// Ordonnance retrouvée par le pharmacien, avec le résultat des contrôles.
class OrdonnanceADelivrer {
  const OrdonnanceADelivrer({
    required this.resume,
    required this.lignes,
    required this.signatureValide,
    this.refus,
  });

  final OrdonnanceResume resume;
  final List<LigneDetail> lignes;
  final bool signatureValide;

  /// Raison du refus de délivrance (null : délivrance possible).
  final String? refus;

  bool get delivrable => refus == null;
}

/// Métier 5 côté pharmacien : contrôle anti-fraude et délivrance, totale ou
/// partielle (quantite_delivree < quantite_boites).
class DelivranceManager {
  DelivranceManager({
    OrdonnanceRepository? ordonnances,
    LigneOrdonnanceRepository? lignes,
    OrdonnanceManager? manager,
  })  : _ordonnances = ordonnances ?? OrdonnanceRepository(),
        _lignes = lignes ?? LigneOrdonnanceRepository(),
        _manager = manager ?? OrdonnanceManager();

  final OrdonnanceRepository _ordonnances;
  final LigneOrdonnanceRepository _lignes;
  final OrdonnanceManager _manager;

  /// Ordonnances en attente de délivrance (validées ou partiellement délivrées).
  Future<List<OrdonnanceResume>> enAttente() {
    return _ordonnances.listerResumes(
      statuts: const [StatutOrdonnance.validee, StatutOrdonnance.partiellementDelivree],
    );
  }

  /// Retrouve l'ordonnance d'un QR code ou d'un numéro saisi, et la contrôle :
  /// signature (hash recalculé), statut, date d'expiration.
  Future<OrdonnanceADelivrer> rechercher(String saisie) async {
    final QrOrdonnance? qr = AuthenticiteOrdonnance.lire(saisie);
    if (qr == null) {
      throw const PrescriptionsException('Scannez le QR code ou saisissez le numéro');
    }
    final Ordonnance? o = await _ordonnances.parNumero(qr.numero);
    if (o == null) {
      throw PrescriptionsException('Aucune ordonnance ${qr.numero}');
    }
    return controler(o.id!, hashQr: qr.hash);
  }

  Future<OrdonnanceADelivrer> controler(int ordonnanceId, {String? hashQr}) async {
    final OrdonnanceResume? resume = await _ordonnances.resume(ordonnanceId);
    if (resume == null) {
      throw const PrescriptionsException('Ordonnance introuvable');
    }
    final Ordonnance o = resume.ordonnance;
    final List<LigneDetail> lignes = await _manager.lignesDetaillees(ordonnanceId);
    final List<LigneOrdonnance> brutes = [];
    for (final LigneDetail d in lignes) {
      brutes.add(d.ligne);
    }

    // Le hash est recalculé depuis la base : s'il diffère de celui stocké
    // (ou de celui du QR code), l'ordonnance a été modifiée.
    bool signatureValide = AuthenticiteOrdonnance.verifier(o, brutes);
    if (hashQr != null && hashQr != o.hashSignature) {
      signatureValide = false;
    }

    return OrdonnanceADelivrer(
      resume: resume,
      lignes: lignes,
      signatureValide: signatureValide,
      refus: _refus(o, signatureValide),
    );
  }

  String? _refus(Ordonnance o, bool signatureValide) {
    switch (o.statut) {
      case StatutOrdonnance.brouillon:
        return "Ordonnance non validée par le médecin : délivrance refusée";
      case StatutOrdonnance.annulee:
        return 'Ordonnance annulée : délivrance refusée';
      case StatutOrdonnance.delivree:
        return 'Ordonnance déjà délivrée : délivrance refusée';
      case StatutOrdonnance.expiree:
        return 'Ordonnance expirée le ${Formatters.date(o.dateExpiration)} : délivrance refusée';
      case StatutOrdonnance.validee:
      case StatutOrdonnance.partiellementDelivree:
        break;
    }
    if (o.dateExpiration.isBefore(DatesSql.jour(DateTime.now()))) {
      return 'Ordonnance expirée le ${Formatters.date(o.dateExpiration)} : délivrance refusée';
    }
    if (!signatureValide) {
      return 'Ordonnance modifiée : la signature ne correspond pas, délivrance refusée';
    }
    return null;
  }

  /// Enregistre les boîtes délivrées maintenant (ligne id → nombre de boîtes).
  /// Renvoie le nouveau statut : partiellement délivrée ou délivrée.
  Future<StatutOrdonnance> delivrer(int ordonnanceId, Map<int, int> boitesParLigne) async {
    final OrdonnanceADelivrer controle = await controler(ordonnanceId);
    final String? refus = controle.refus;
    if (refus != null) {
      throw PrescriptionsException(refus);
    }

    int total = 0;
    for (final LigneDetail d in controle.lignes) {
      final int n = boitesParLigne[d.ligne.id] ?? 0;
      if (n < 0 || n > d.ligne.resteADelivrer) {
        throw PrescriptionsException(
          '${d.medicament.libelle} : au plus ${d.ligne.resteADelivrer} boîte(s) à délivrer',
        );
      }
      total += n;
    }
    if (total == 0) {
      throw const PrescriptionsException('Indiquez au moins une boîte à délivrer');
    }

    final Database db = await PrescriptionsSchema.database;
    return db.transaction((Transaction txn) async {
      bool complete = true;
      for (final LigneDetail d in controle.lignes) {
        final int n = boitesParLigne[d.ligne.id] ?? 0;
        final int delivree = d.ligne.quantiteDelivree + n;
        if (n > 0) {
          await _lignes.enregistrerDelivrance(d.ligne.id!, delivree, exec: txn);
        }
        if (delivree < d.ligne.quantiteBoites) {
          complete = false;
        }
      }
      final StatutOrdonnance statut =
          complete ? StatutOrdonnance.delivree : StatutOrdonnance.partiellementDelivree;
      await _ordonnances.changerStatut(ordonnanceId, statut, exec: txn);
      return statut;
    });
  }
}
