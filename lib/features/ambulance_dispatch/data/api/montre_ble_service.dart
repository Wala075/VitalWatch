import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/surveillance_cardiaque.dart';
import 'mibro_protocole.dart';

/// État de la liaison Bluetooth avec la montre.
enum EtatMontre {
  indisponible('Bluetooth indisponible sur cet appareil'),
  bluetoothEteint('Active le Bluetooth du téléphone'),
  introuvable('Montre introuvable : allume-la et approche-la du téléphone'),
  incompatible("Appareil trouvé, mais ce n'est pas une Mibro C2"),
  deconnectee('Montre déconnectée'),
  connectee('Montre connectée en Bluetooth');

  const EtatMontre(this.libelle);

  final String libelle;
}

/// Erreur de lecture de la montre (message affichable tel quel).
class MontreException implements Exception {
  const MontreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lecture directe du rythme cardiaque de la montre Mibro C2 en Bluetooth LE,
/// sans passer par Mibro Fit / Google Fit / Health Connect.
///
/// La montre mesure toute seule toutes les 5 min (plus les mesures lancées
/// à la main sur la montre) et garde les relevés de la journée.
/// [mesures] lui demande ces relevés.
class MontreBleService {
  BluetoothDevice? _montre;
  BluetoothCharacteristic? _ecriture;
  StreamSubscription<List<int>>? _abonnementDonnees;
  StreamSubscription<BluetoothConnectionState>? _abonnementEtat;
  final AssembleurPaquets _assembleur = AssembleurPaquets();

  /// Relevés reçus, un par horodatage (la montre renvoie toute la journée
  /// à chaque demande, les doublons sont donc écrasés).
  final Map<DateTime, MesureCardiaque> _releves = {};
  DateTime? _dernierReleveRecuA;

  /// Garde la montre trouvée tant que l'app est ouverte.
  static String? _idMemorise;

  EtatMontre _etat = EtatMontre.deconnectee;
  EtatMontre get etat => _etat;

  int? _batterie;
  int? get batterie => _batterie;

  bool _enCharge = false;
  bool get enCharge => _enCharge;

  /// Version du logiciel de la montre et modèle (service « Device Information »).
  String? _firmware;
  String? get firmware => _firmware;
  String? _modele;
  String? get modele => _modele;

  /// Qualité du signal Bluetooth (dBm, ex. -55 = excellent, -85 = faible).
  int? _signal;
  int? get signal => _signal;

  DateTime? _derniereSynchro;
  DateTime? get derniereSynchro => _derniereSynchro;

  /// Activité de la journée, une entrée par heure (paquets `51 20`).
  final Map<DateTime, ResumeActivite> _activite = {};

  int get pasAujourdhui {
    int total = 0;
    for (final ResumeActivite a in _activiteDuJour()) {
      total += a.pas;
    }
    return total;
  }

  int get caloriesAujourdhui {
    int total = 0;
    for (final ResumeActivite a in _activiteDuJour()) {
      total += a.calories;
    }
    return total;
  }

  /// Activité d'aujourd'hui heure par heure (pas, calories), dans l'ordre.
  List<ResumeActivite> get activiteDuJour {
    final List<ResumeActivite> res = _activiteDuJour();
    res.sort((ResumeActivite a, ResumeActivite b) => a.heure.compareTo(b.heure));
    return res;
  }

  /// Relevés cardiaques d'aujourd'hui (statistiques min / moyenne / max).
  List<MesureCardiaque> get relevesAujourdhui {
    final DateTime minuit = _minuit();
    final List<MesureCardiaque> res = [];
    for (final MesureCardiaque m in _releves.values) {
      if (!m.date.isBefore(minuit)) {
        res.add(m);
      }
    }
    return res;
  }

  List<ResumeActivite> _activiteDuJour() {
    final DateTime minuit = _minuit();
    final List<ResumeActivite> res = [];
    for (final ResumeActivite a in _activite.values) {
      if (!a.heure.isBefore(minuit)) {
        res.add(a);
      }
    }
    return res;
  }

  DateTime _minuit() {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String get nomMontre {
    final BluetoothDevice? m = _montre;
    if (m == null || m.platformName.isEmpty) {
      return 'Mibro C2';
    }
    return m.platformName;
  }

  // ============================================================
  // CONNEXION
  // ============================================================

  Future<EtatMontre> connecter() async {
    if (_etat == EtatMontre.connectee) {
      return _etat;
    }
    try {
      if (!await FlutterBluePlus.isSupported) {
        return _etat = EtatMontre.indisponible;
      }

      final BluetoothAdapterState adaptateur = await FlutterBluePlus.adapterState
          .where((BluetoothAdapterState s) => s != BluetoothAdapterState.unknown)
          .first
          .timeout(const Duration(seconds: 3));
      if (adaptateur != BluetoothAdapterState.on) {
        return _etat = EtatMontre.bluetoothEteint;
      }

      final BluetoothDevice? montre = await _trouver();
      if (montre == null) {
        return _etat = EtatMontre.introuvable;
      }

      await montre.connect(
        license: License.nonprofit, // projet étudiant
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      BluetoothCharacteristic? ecriture;
      BluetoothCharacteristic? notification;
      final List<BluetoothService> services = await montre.discoverServices();
      for (final BluetoothService s in services) {
        for (final BluetoothCharacteristic c in s.characteristics) {
          final String uuid = c.uuid.toString().toLowerCase();
          if (uuid == MibroProtocole.uuidEcriture) {
            ecriture = c;
          }
          if (uuid == MibroProtocole.uuidNotification) {
            notification = c;
          }
        }
      }
      if (ecriture == null || notification == null) {
        await montre.disconnect();
        return _etat = EtatMontre.incompatible;
      }
      await _lireInformations(services);

      await _abonnementDonnees?.cancel();
      await notification.setNotifyValue(true);
      _abonnementDonnees = notification.onValueReceived.listen(_recevoir);

      await _abonnementEtat?.cancel();
      _abonnementEtat = montre.connectionState.listen((BluetoothConnectionState s) {
        if (s == BluetoothConnectionState.disconnected && _etat == EtatMontre.connectee) {
          _etat = EtatMontre.deconnectee;
        }
      });

      _montre = montre;
      _ecriture = ecriture;
      _idMemorise = montre.remoteId.str;
      return _etat = EtatMontre.connectee;
    } on TimeoutException {
      return _etat = EtatMontre.introuvable;
    } catch (_) {
      return _etat = EtatMontre.deconnectee;
    }
  }

  /// Firmware + modèle via le service standard « Device Information »
  /// (lecture seule, ignorée si la montre ne l'expose pas).
  Future<void> _lireInformations(List<BluetoothService> services) async {
    for (final BluetoothService s in services) {
      for (final BluetoothCharacteristic c in s.characteristics) {
        final String uuid = c.uuid.toString().toLowerCase();
        final bool firmware = uuid == MibroProtocole.uuidFirmware;
        final bool modele = uuid == MibroProtocole.uuidModele;
        if ((!firmware && !modele) || !c.properties.read) {
          continue;
        }
        try {
          final String texte = String.fromCharCodes(await c.read()).trim();
          if (texte.isEmpty) {
            continue;
          }
          if (firmware) {
            _firmware = texte;
          } else {
            _modele = texte;
          }
        } catch (_) {
          // caractéristique illisible : on s'en passe
        }
      }
    }
  }

  /// Met à jour la qualité du signal Bluetooth.
  Future<void> lireSignal() async {
    final BluetoothDevice? m = _montre;
    if (m == null || _etat != EtatMontre.connectee) {
      return;
    }
    try {
      _signal = await m.readRssi();
    } catch (_) {
      // lecture impossible (montre en train de se déconnecter)
    }
  }

  Future<void> deconnecter() async {
    await _abonnementDonnees?.cancel();
    _abonnementDonnees = null;
    await _abonnementEtat?.cancel();
    _abonnementEtat = null;
    try {
      // Ferme seulement notre liaison : Mibro Fit garde la sienne.
      await _montre?.disconnect();
    } catch (_) {
      // déjà déconnectée
    }
    _etat = EtatMontre.deconnectee;
  }

  /// 1. parmi les appareils déjà connectés (Mibro Fit) ou appairés ;
  /// 2. sinon scan Bluetooth (qui demande aussi les autorisations) ;
  /// 3. puis nouvel essai parmi les connus (autorisations accordées entre-temps).
  Future<BluetoothDevice?> _trouver() async {
    final BluetoothDevice? connue = await _parmiConnus();
    if (connue != null) {
      return connue;
    }
    final BluetoothDevice? scannee = await _scanner();
    if (scannee != null) {
      return scannee;
    }
    return _parmiConnus();
  }

  Future<BluetoothDevice?> _parmiConnus() async {
    final List<BluetoothDevice> connus = [];
    try {
      connus.addAll(await FlutterBluePlus.systemDevices([]));
    } catch (_) {
      // autorisation pas encore accordée
    }
    try {
      connus.addAll(await FlutterBluePlus.bondedDevices);
    } catch (_) {
      // Android uniquement
    }
    for (final BluetoothDevice d in connus) {
      if (d.remoteId.str == _idMemorise || MibroProtocole.estMontre(d.platformName)) {
        return d;
      }
    }
    return null;
  }

  Future<BluetoothDevice?> _scanner() async {
    final Completer<BluetoothDevice?> trouvee = Completer<BluetoothDevice?>();
    final StreamSubscription<List<ScanResult>> abonnement =
        FlutterBluePlus.onScanResults.listen((List<ScanResult> resultats) {
      for (final ScanResult r in resultats) {
        final String nom = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;
        if (MibroProtocole.estMontre(nom) && !trouvee.isCompleted) {
          trouvee.complete(r.device);
        }
      }
    });
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      final Future<BluetoothDevice?> finScan = FlutterBluePlus.isScanning
          .where((bool enCours) => !enCours)
          .first
          .then<BluetoothDevice?>((_) => null);
      return await Future.any<BluetoothDevice?>([trouvee.future, finScan]);
    } catch (_) {
      return null;
    } finally {
      await abonnement.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // scan déjà arrêté
      }
    }
  }

  // ============================================================
  // DONNÉES
  // ============================================================

  void _recevoir(List<int> morceau) {
    for (final List<int> paquet in _assembleur.ajouter(morceau)) {
      final MesureCardiaque? m = MibroProtocole.releveCardiaque(paquet);
      if (m != null) {
        _releves[m.date] = m;
        _dernierReleveRecuA = DateTime.now();
        continue;
      }
      final ResumeActivite? activite = MibroProtocole.resumeActivite(paquet);
      if (activite != null) {
        _activite[activite.heure] = activite;
        continue;
      }
      final EtatBatterie? batterie = MibroProtocole.batterie(paquet);
      if (batterie != null) {
        _batterie = batterie.niveau;
        _enCharge = batterie.enCharge;
      }
    }
  }

  /// Relevés de la montre sur [periode], du plus ancien au plus récent.
  /// Même contrat que la lecture Health Connect : l'écran ne change pas.
  Future<List<MesureCardiaque>> mesures({
    Duration periode = const Duration(hours: 3),
  }) async {
    if (_etat != EtatMontre.connectee) {
      final EtatMontre e = await connecter();
      if (e != EtatMontre.connectee) {
        throw MontreException(e.libelle);
      }
    }
    final BluetoothCharacteristic ecriture = _ecriture!;

    final DateTime maintenant = DateTime.now();
    final DateTime debutJournee = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final DateTime? avant = _dernierReleveRecuA;

    await ecriture.write(
      MibroProtocole.demandeReleves(debutJournee),
      withoutResponse: ecriture.properties.writeWithoutResponse,
    );

    // La montre envoie ses relevés en ~2 s : on attend 1,5 s sans nouveau
    // relevé (8 s maximum).
    final DateTime limite = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(limite)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final DateTime? dernier = _dernierReleveRecuA;
      if (dernier != null &&
          dernier != avant &&
          DateTime.now().difference(dernier) > const Duration(milliseconds: 1500)) {
        break;
      }
    }

    _derniereSynchro = DateTime.now();
    await lireSignal();

    final DateTime debut = maintenant.subtract(periode);
    final List<MesureCardiaque> res = [];
    for (final MesureCardiaque m in _releves.values) {
      if (!m.date.isBefore(debut)) {
        res.add(m);
      }
    }
    res.sort((MesureCardiaque a, MesureCardiaque b) => a.date.compareTo(b.date));
    return res;
  }
}
