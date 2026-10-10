import 'package:latlong2/latlong.dart';

/// Gravité de l'urgence. [priorite] : 1 = la plus urgente.
enum Gravite {
  critique('critique', 'Critique', 1),
  urgente('urgente', 'Urgente', 2),
  moderee('moderee', 'Modérée', 3),
  faible('faible', 'Faible', 4);

  const Gravite(this.code, this.libelle, this.priorite);

  final String code;
  final String libelle;
  final int priorite;

  static Gravite depuisCode(String? code) {
    for (final Gravite g in Gravite.values) {
      if (g.code == code) {
        return g;
      }
    }
    return Gravite.moderee;
  }
}

enum StatutIntervention {
  enAttente('en_attente', 'En attente'),
  assignee('assignee', 'Ambulance assignée'),
  enRoute('en_route', 'En route'),
  surPlace('sur_place', 'Sur place'),
  transport('transport', 'Transport hôpital'),
  terminee('terminee', 'Terminée'),
  annulee('annulee', 'Annulée');

  const StatutIntervention(this.code, this.libelle);

  final String code;
  final String libelle;

  /// Une ambulance est engagée sur l'intervention.
  bool get estActive =>
      this == assignee || this == enRoute || this == surPlace || this == transport;

  /// Intervention pas encore clôturée.
  bool get estOuverte => this == enAttente || estActive;

  static StatutIntervention depuisCode(String? code) {
    for (final StatutIntervention s in StatutIntervention.values) {
      if (s.code == code) {
        return s;
      }
    }
    return StatutIntervention.enAttente;
  }
}

/// D'où vient la demande de secours.
enum OrigineIntervention {
  appel('appel', 'Appel'),
  sos('sos', 'SOS'),
  alerte('alerte', 'Alerte vitale');

  const OrigineIntervention(this.code, this.libelle);

  final String code;
  final String libelle;

  static OrigineIntervention depuisCode(String? code) {
    for (final OrigineIntervention o in OrigineIntervention.values) {
      if (o.code == code) {
        return o;
      }
    }
    return OrigineIntervention.appel;
  }
}

class Intervention {
  final int? id;
  final int? ambulanceId;
  final int? patientId;
  final int? alerteId;
  final String adresse;
  final double lat;
  final double lng;
  final Gravite gravite;
  final StatutIntervention statut;
  final OrigineIntervention origine;
  final DateTime heureAppel;
  final DateTime? heureDepart;
  final DateTime? heureArrivee;
  final String? hopitalDestination;

  const Intervention({
    this.id,
    this.ambulanceId,
    this.patientId,
    this.alerteId,
    required this.adresse,
    required this.lat,
    required this.lng,
    required this.gravite,
    this.statut = StatutIntervention.enAttente,
    this.origine = OrigineIntervention.appel,
    required this.heureAppel,
    this.heureDepart,
    this.heureArrivee,
    this.hopitalDestination,
  });

  LatLng get position => LatLng(lat, lng);

  /// Temps de réponse = appel → arrivée sur place.
  Duration? get tempsReponse {
    final DateTime? arrivee = heureArrivee;
    if (arrivee == null) {
      return null;
    }
    return arrivee.difference(heureAppel);
  }

  Intervention copyWith({
    int? id,
    int? ambulanceId,
    StatutIntervention? statut,
    DateTime? heureDepart,
    DateTime? heureArrivee,
    String? hopitalDestination,
  }) {
    return Intervention(
      id: id ?? this.id,
      ambulanceId: ambulanceId ?? this.ambulanceId,
      patientId: patientId,
      alerteId: alerteId,
      adresse: adresse,
      lat: lat,
      lng: lng,
      gravite: gravite,
      statut: statut ?? this.statut,
      origine: origine,
      heureAppel: heureAppel,
      heureDepart: heureDepart ?? this.heureDepart,
      heureArrivee: heureArrivee ?? this.heureArrivee,
      hopitalDestination: hopitalDestination ?? this.hopitalDestination,
    );
  }

  factory Intervention.fromMap(Map<String, Object?> map) {
    return Intervention(
      id: map['id'] as int?,
      ambulanceId: map['ambulance_id'] as int?,
      patientId: map['patient_id'] as int?,
      alerteId: map['alerte_id'] as int?,
      adresse: (map['adresse'] as String?) ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      gravite: Gravite.depuisCode(map['gravite'] as String?),
      statut: StatutIntervention.depuisCode(map['statut'] as String?),
      origine: OrigineIntervention.depuisCode(map['origine'] as String?),
      heureAppel: DateTime.parse(map['heure_appel'] as String),
      heureDepart: _date(map['heure_depart']),
      heureArrivee: _date(map['heure_arrivee']),
      hopitalDestination: map['hopital_destination'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'ambulance_id': ambulanceId,
      'patient_id': patientId,
      'alerte_id': alerteId,
      'adresse': adresse,
      'lat': lat,
      'lng': lng,
      'gravite': gravite.code,
      'statut': statut.code,
      'origine': origine.code,
      'heure_appel': heureAppel.toIso8601String(),
      'heure_depart': heureDepart?.toIso8601String(),
      'heure_arrivee': heureArrivee?.toIso8601String(),
      'hopital_destination': hopitalDestination,
    };
  }

  static DateTime? _date(Object? valeur) {
    if (valeur is String && valeur.isNotEmpty) {
      return DateTime.parse(valeur);
    }
    return null;
  }
}
