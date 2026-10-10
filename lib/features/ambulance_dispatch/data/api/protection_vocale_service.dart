import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Point d'entrée de l'isolat du service de premier plan.
@pragma('vm:entry-point')
void demarrerTacheProtectionVocale() {
  FlutterForegroundTask.setTaskHandler(_TacheProtectionVocale());
}

/// Isolat du service : il ne fait que relayer les boutons de la notification
/// (« Annuler ») vers l'application. L'écoute elle-même tourne dans l'app.
class _TacheProtectionVocale extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain(id);
  }
}

/// Protection vocale permanente (Android) : un service de premier plan
/// (notification fixe, micro + GPS autorisés) garde l'application active
/// quand elle est en arrière-plan ou que l'écran est verrouillé, pour que
/// « help » / « au secours » soit entendu partout.
class ProtectionVocale {
  ProtectionVocale._();

  static final ProtectionVocale instance = ProtectionVocale._();

  static const String boutonAnnuler = 'annuler';
  static const String _cle = 'protection_vocale';
  static const String _titre = 'VitalWatch · protection vocale active';
  static const String _texteEcoute =
      'Dites « help » ou « au secours » : une ambulance sera envoyée';

  final StreamController<String> _boutons = StreamController<String>.broadcast();
  bool _initialise = false;

  /// Boutons pressés dans la notification (ex. [boutonAnnuler]).
  Stream<String> get boutons => _boutons.stream;

  void _initialiser() {
    if (_initialise) {
      return;
    }
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'vitalwatch_protection_vocale',
        channelName: 'Protection vocale',
        channelDescription: 'Écoute « help » même écran verrouillé',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    FlutterForegroundTask.addTaskDataCallback(_recevoir);
    _initialise = true;
  }

  void _recevoir(Object data) {
    if (data is String) {
      _boutons.add(data);
    }
  }

  /// Démarre le service (l'app doit être au premier plan). Renvoie un
  /// message d'erreur, ou null si la protection est active.
  Future<String?> demarrer({required bool localisation}) async {
    try {
      _initialiser();
      final NotificationPermission notif =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notif != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (await FlutterForegroundTask.isRunningService) {
        return null;
      }
      final ServiceRequestResult r = await FlutterForegroundTask.startService(
        serviceId: 3110,
        notificationTitle: _titre,
        notificationText: _texteEcoute,
        callback: demarrerTacheProtectionVocale,
        serviceTypes: [
          ForegroundServiceTypes.microphone,
          if (localisation) ForegroundServiceTypes.location,
        ],
      );
      return r is ServiceRequestFailure ? '$r' : null;
    } catch (e) {
      return '$e';
    }
  }

  Future<void> arreter() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {
      // service déjà arrêté
    }
  }

  /// Texte de la notification (visible écran verrouillé) ; [annulable] ajoute
  /// le bouton « Annuler » pendant le compte à rebours.
  Future<void> afficher(String titre, String texte, {bool annulable = false}) async {
    try {
      if (!await FlutterForegroundTask.isRunningService) {
        return;
      }
      await FlutterForegroundTask.updateService(
        notificationTitle: titre,
        notificationText: texte,
        notificationButtons: annulable
            ? const [NotificationButton(id: boutonAnnuler, text: 'Annuler')]
            : const [],
      );
    } catch (_) {
      // notification facultative
    }
  }

  Future<void> afficherEcoute() => afficher(_titre, _texteEcoute);

  /// Préférence « même écran verrouillé » gardée d'un lancement à l'autre.
  Future<bool> preference() async {
    try {
      final Object? v = await FlutterForegroundTask.getData(key: _cle);
      return v == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> enregistrerPreference(bool oui) async {
    try {
      await FlutterForegroundTask.saveData(key: _cle, value: oui);
    } catch (_) {
      // préférence facultative
    }
  }
}
