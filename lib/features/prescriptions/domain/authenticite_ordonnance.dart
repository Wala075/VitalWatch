import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'dates_sql.dart';
import 'models/ligne_ordonnance.dart';
import 'models/ordonnance.dart';

/// Métier 5 : signature anti-fraude de l'ordonnance.
///
/// SHA-256 de : numéro + patient + médecin + date + lignes triées.
/// Le QR code contient le numéro et ce hash ; au scan, le hash est recalculé.
class AuthenticiteOrdonnance {
  AuthenticiteOrdonnance._();

  static String signer(Ordonnance o, List<LigneOrdonnance> lignes) {
    final List<LigneOrdonnance> tri = List<LigneOrdonnance>.of(lignes);
    tri.sort((LigneOrdonnance a, LigneOrdonnance b) =>
        a.medicamentId.compareTo(b.medicamentId));

    final StringBuffer buffer = StringBuffer(
      '${o.numero}|${o.patientId}|${o.medecinId}|${DatesSql.date(o.dateEmission)}',
    );
    for (final LigneOrdonnance l in tri) {
      buffer.write('|${l.medicamentId}:${l.dosePrise}x${l.prisesParJour}x${l.dureeJours}');
    }
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  /// false si l'ordonnance n'est pas signée ou a été modifiée après validation.
  static bool verifier(Ordonnance o, List<LigneOrdonnance> lignes) {
    final String? hash = o.hashSignature;
    return hash != null && hash == signer(o, lignes);
  }

  static const String _prefixeQr = 'VITALWATCH';

  /// Contenu du QR code imprimé sur l'ordonnance.
  static String contenuQr(Ordonnance o) {
    return '$_prefixeQr|${o.numero}|${o.hashSignature ?? ''}';
  }

  /// Lit un QR code VitalWatch ou un numéro saisi à la main (ORD-2026-0001).
  static QrOrdonnance? lire(String saisie) {
    final String t = saisie.trim();
    if (t.isEmpty) {
      return null;
    }
    final List<String> parties = t.split('|');
    if (parties.length == 3 && parties[0] == _prefixeQr) {
      final String hash = parties[2].trim();
      return QrOrdonnance(numero: parties[1].trim(), hash: hash.isEmpty ? null : hash);
    }
    return QrOrdonnance(numero: t.toUpperCase());
  }
}

/// Contenu lu sur une ordonnance : numéro, et hash si c'est un QR code.
class QrOrdonnance {
  const QrOrdonnance({required this.numero, this.hash});

  final String numero;
  final String? hash;
}
