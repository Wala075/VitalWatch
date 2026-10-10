import 'package:health/health.dart';

import '../../domain/surveillance_cardiaque.dart';

/// État de l'accès aux données de santé du téléphone.
enum AccesSante {
  indisponible('Health Connect indisponible sur cet appareil'),
  aInstaller('Health Connect doit être installé ou mis à jour'),
  nonAutorise("Accès au rythme cardiaque non autorisé"),
  autorise('Montre connectée via Health Connect');

  const AccesSante(this.libelle);

  final String libelle;
}

/// Lecture du rythme cardiaque de la montre (Mibro C2 → Mibro Fit →
/// Google Fit → Health Connect) avec le package health.
class MontreCardiaqueService {
  final Health _health = Health();
  bool _configure = false;

  static const List<HealthDataType> _types = [HealthDataType.HEART_RATE];
  static const List<HealthDataAccess> _acces = [HealthDataAccess.READ];

  Future<void> _configurer() async {
    if (!_configure) {
      await _health.configure();
      _configure = true;
    }
  }

  Future<AccesSante> etat() async {
    try {
      await _configurer();
      final HealthConnectSdkStatus? statut = await _health.getHealthConnectSdkStatus();
      if (statut == HealthConnectSdkStatus.sdkUnavailable) {
        return AccesSante.indisponible;
      }
      if (statut == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        return AccesSante.aInstaller;
      }
      final bool? ok = await _health.hasPermissions(_types, permissions: _acces);
      return ok == true ? AccesSante.autorise : AccesSante.nonAutorise;
    } catch (_) {
      // Plateforme non prise en charge (Windows, émulateur sans Health Connect...)
      return AccesSante.indisponible;
    }
  }

  Future<void> installer() => _health.installHealthConnect();

  /// Ouvre l'écran d'autorisation Health Connect.
  Future<bool> autoriser() async {
    await _configurer();
    return _health.requestAuthorization(_types, permissions: _acces);
  }

  /// Mesures des dernières heures, de la plus ancienne à la plus récente.
  Future<List<MesureCardiaque>> mesures({
    Duration periode = const Duration(hours: 3),
  }) async {
    await _configurer();
    final DateTime fin = DateTime.now();
    final List<HealthDataPoint> points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: fin.subtract(periode),
      endTime: fin,
    );
    final List<HealthDataPoint> uniques = _health.removeDuplicates(points);

    final List<MesureCardiaque> res = [];
    for (final HealthDataPoint p in uniques) {
      final HealthValue v = p.value;
      if (v is NumericHealthValue) {
        res.add(MesureCardiaque(
          bpm: v.numericValue.round(),
          date: p.dateTo,
          source: p.sourceName == 'com.xiaoxun.xunoversea.mibrofit' ? 'Mibro Fit' : p.sourceName,
        ));
      }
    }
    res.sort((MesureCardiaque a, MesureCardiaque b) => a.date.compareTo(b.date));
    return res;
  }
}
