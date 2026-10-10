import '../../domain/surveillance_cardiaque.dart';

/// Protocole Bluetooth LE de la montre Mibro C2.
///
/// Décodé à partir des échanges entre Mibro Fit et la montre (journal HCI
/// Bluetooth Android). Même famille que la Makibes HR3 de Gadgetbridge.
///
/// Service UART Nordic :
/// - `6e400002` : téléphone → montre (écriture sans réponse)
/// - `6e400003` : montre → téléphone (notifications)
///
/// Paquet : `AB 00 LEN FF CMD SOUS données...` (LEN = nombre d'octets après LEN).
///
/// | Paquet            | Contenu                                         |
/// |-------------------|-------------------------------------------------|
/// | `51 11`           | relevé cardiaque : AA MM JJ hh mm BPM           |
/// | `51 20`           | résumé horaire : AA MM JJ hh 00, pas, calories  |
/// | `91 80`           | batterie : en charge (0/1), niveau %            |
class MibroProtocole {
  static const String uuidEcriture = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const String uuidNotification = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  static const int entete = 0xAB;
  static const int cmdDonnees = 0x51;
  static const int sousCardiaque = 0x11;
  static const int sousActivite = 0x20;
  static const int cmdBatterie = 0x91;

  /// Service Bluetooth standard « Device Information » (lecture seule).
  static const String uuidFirmware = '00002a26-0000-1000-8000-00805f9b34fb';
  static const String uuidModele = '00002a24-0000-1000-8000-00805f9b34fb';

  /// Noms Bluetooth possibles de la montre (la Mibro C2 s'annonce « XPAW009 »).
  static const List<String> nomsMontre = ['xpaw', 'mibro'];

  static bool estMontre(String nom) {
    final String n = nom.toLowerCase();
    for (final String m in nomsMontre) {
      if (n.contains(m)) {
        return true;
      }
    }
    return false;
  }

  /// Commande téléphone → montre : `AB 00 LEN FF CMD 80 args...`
  static List<int> commande(int cmd, List<int> args) {
    return [entete, 0x00, args.length + 3, 0xFF, cmd, 0x80, ...args];
  }

  /// Demande les relevés enregistrés (pas + cardio) depuis [depuis].
  /// En pratique la montre renvoie toute la journée.
  static List<int> demandeReleves(DateTime depuis) {
    final int a = depuis.year - 2000;
    return commande(cmdDonnees, [
      0x00,
      a, depuis.month, depuis.day, depuis.hour, depuis.minute, // pas
      a, depuis.month, depuis.day, depuis.hour, depuis.minute, // cardio
    ]);
  }

  /// Relevé cardiaque d'un paquet `51 11`, sinon null.
  /// Ex. `AB 00 0B FF 51 11 1A 0A 04 11 1E 55 55 11` → 04/10/2026 17:30, 85 bpm.
  static MesureCardiaque? releveCardiaque(List<int> p) {
    if (p.length < 12 ||
        p[0] != entete ||
        p[3] != 0xFF ||
        p[4] != cmdDonnees ||
        p[5] != sousCardiaque) {
      return null;
    }
    final int bpm = p[11];
    if (bpm < 25 || bpm > 250) {
      return null; // 0 = pas de mesure (montre non portée)
    }
    final int mois = p[7];
    final int jour = p[8];
    final int heure = p[9];
    final int minute = p[10];
    if (mois < 1 || mois > 12 || jour < 1 || jour > 31 || heure > 23 || minute > 59) {
      return null;
    }
    return MesureCardiaque(
      bpm: bpm,
      date: DateTime(2000 + p[6], mois, jour, heure, minute),
      source: 'Mibro C2',
    );
  }

  /// Niveau de batterie d'un paquet `91`, sinon null.
  /// Ex. `AB 00 05 FF 91 80 00 2C` → 44 %.
  static int? niveauBatterie(List<int> p) {
    return batterie(p)?.niveau;
  }

  /// Batterie complète d'un paquet `91` : niveau + en charge (octet 6 = 1).
  static EtatBatterie? batterie(List<int> p) {
    if (p.length < 8 || p[0] != entete || p[4] != cmdBatterie) {
      return null;
    }
    final int niveau = p[7];
    if (niveau > 100) {
      return null;
    }
    return EtatBatterie(niveau: niveau, enCharge: p[6] == 1);
  }

  /// Résumé horaire d'un paquet `51 20` : AA MM JJ hh 00, pas (2 octets),
  /// calories (3 octets). Ex. `… 51 20 1A 0A 04 0E 00 04 DF 00 00 3D …`
  /// → 04/10/2026 14 h : 1247 pas, 61 kcal.
  static ResumeActivite? resumeActivite(List<int> p) {
    if (p.length < 16 ||
        p[0] != entete ||
        p[3] != 0xFF ||
        p[4] != cmdDonnees ||
        p[5] != sousActivite) {
      return null;
    }
    final int mois = p[7];
    final int jour = p[8];
    final int heure = p[9];
    if (mois < 1 || mois > 12 || jour < 1 || jour > 31 || heure > 23) {
      return null;
    }
    return ResumeActivite(
      heure: DateTime(2000 + p[6], mois, jour, heure),
      pas: (p[11] << 8) | p[12],
      calories: (p[13] << 16) | (p[14] << 8) | p[15],
    );
  }
}

class EtatBatterie {
  const EtatBatterie({required this.niveau, required this.enCharge});

  final int niveau;
  final bool enCharge;
}

/// Activité d'une heure de la journée (paquet `51 20`).
class ResumeActivite {
  const ResumeActivite({required this.heure, required this.pas, required this.calories});

  final DateTime heure;
  final int pas;
  final int calories;
}

/// Recolle les paquets que le Bluetooth coupe en morceaux de 20 octets
/// (ex. un paquet `51 20` de 25 octets arrive en 20 + 6).
class AssembleurPaquets {
  final List<int> _tampon = [];

  /// Ajoute un morceau reçu et renvoie les paquets complets.
  List<List<int>> ajouter(List<int> morceau) {
    final List<List<int>> complets = [];
    if (morceau.isEmpty) {
      return complets;
    }

    final bool nouveauPaquet = morceau[0] == MibroProtocole.entete;

    // Un nouveau paquet commence alors que le précédent est incomplet :
    // on rend quand même ce qu'on a.
    if (nouveauPaquet && _tampon.isNotEmpty) {
      complets.add(List<int>.from(_tampon));
      _tampon.clear();
    }

    // Morceau orphelin (bourrage, fin déjà traitée) : ignoré.
    if (_tampon.isEmpty && !nouveauPaquet) {
      return complets;
    }

    _tampon.addAll(morceau);

    while (_tampon.length >= 3) {
      final int attendu = 3 + ((_tampon[1] << 8) | _tampon[2]);
      if (_tampon.length < attendu) {
        break; // on attend la suite
      }
      complets.add(_tampon.sublist(0, attendu));
      _tampon.removeRange(0, attendu);
      if (_tampon.isNotEmpty && _tampon[0] != MibroProtocole.entete) {
        _tampon.clear();
      }
    }
    return complets;
  }
}
