import '../../../models/medecin.dart';

/// Plage de consultation d'un médecin sur un jour de la semaine.
class Creneau {
  const Creneau({
    this.id,
    required this.medecinId,
    required this.jour,
    required this.debut,
    required this.fin,
  });

  final int? id;
  final int medecinId;

  /// 1 = lundi … 7 = dimanche (comme DateTime.weekday).
  final int jour;

  /// Minutes depuis minuit (ex. 8 h 30 = 510).
  final int debut;
  final int fin;

  int get duree => fin - debut;

  String get libelle => '${Horaire.format(debut)} – ${Horaire.format(fin)}';

  factory Creneau.fromMap(Map<String, Object?> map) {
    return Creneau(
      id: map['id'] as int?,
      medecinId: map['medecin_id'] as int,
      jour: map['jour'] as int,
      debut: map['debut'] as int,
      fin: map['fin'] as int,
    );
  }

  Map<String, Object?> toMap() {
    return {'medecin_id': medecinId, 'jour': jour, 'debut': debut, 'fin': fin};
  }
}

class Horaire {
  Horaire._();

  static const List<String> jours = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
  ];

  static const List<String> joursCourts = [
    'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim',
  ];

  /// 510 -> « 08:30 »
  static String format(int minutes) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static int heuresParSemaine(List<Creneau> creneaux) {
    int total = 0;
    for (final Creneau c in creneaux) {
      total += c.duree;
    }
    return (total / 60).round();
  }

  static int joursTravailles(List<Creneau> creneaux) {
    final Set<int> jours = {};
    for (final Creneau c in creneaux) {
      jours.add(c.jour);
    }
    return jours.length;
  }
}

/// État d'un médecin à un instant donné.
enum EtatMedecin { enService, horsHoraires, absent }

class Disponibilite {
  const Disponibilite(this.etat, {this.jusqua, this.reprise});

  final EtatMedecin etat;

  /// Fin du créneau en cours (si en service).
  final DateTime? jusqua;

  /// Début du prochain créneau (si hors horaires).
  final DateTime? reprise;

  String libelle(DateTime maintenant) {
    switch (etat) {
      case EtatMedecin.absent:
        return 'En congé';
      case EtatMedecin.enService:
        final DateTime? fin = jusqua;
        return fin == null ? 'En service' : "En service jusqu'à ${_heure(fin)}";
      case EtatMedecin.horsHoraires:
        final DateTime? r = reprise;
        if (r == null) {
          return 'Aucun horaire défini';
        }
        final DateTime aujourdHui =
            DateTime(maintenant.year, maintenant.month, maintenant.day);
        final int ecart =
            DateTime(r.year, r.month, r.day).difference(aujourdHui).inDays;
        if (ecart == 0) {
          return 'Reprend à ${_heure(r)}';
        }
        if (ecart == 1) {
          return 'Reprend demain à ${_heure(r)}';
        }
        return 'Reprend ${Horaire.jours[r.weekday - 1].toLowerCase()} à ${_heure(r)}';
    }
  }

  static String _heure(DateTime d) => Horaire.format(d.hour * 60 + d.minute);

  /// Règle métier : en congé > en service (dans un créneau) > hors horaires
  /// (avec la date de reprise la plus proche, sur 7 jours).
  static Disponibilite calculer(
    Medecin medecin,
    List<Creneau> creneaux,
    DateTime maintenant,
  ) {
    if (!medecin.disponible) {
      return const Disponibilite(EtatMedecin.absent);
    }
    final int minute = maintenant.hour * 60 + maintenant.minute;

    for (final Creneau c in creneaux) {
      if (c.jour == maintenant.weekday && c.debut <= minute && minute < c.fin) {
        return Disponibilite(
          EtatMedecin.enService,
          jusqua: DateTime(maintenant.year, maintenant.month, maintenant.day, 0, c.fin),
        );
      }
    }

    for (int d = 0; d <= 7; d++) {
      final DateTime jour =
          DateTime(maintenant.year, maintenant.month, maintenant.day + d);
      Creneau? premier;
      for (final Creneau c in creneaux) {
        if (c.jour != jour.weekday) {
          continue;
        }
        if (d == 0 && c.debut <= minute) {
          continue;
        }
        if (premier == null || c.debut < premier.debut) {
          premier = c;
        }
      }
      if (premier != null) {
        return Disponibilite(
          EtatMedecin.horsHoraires,
          reprise: DateTime(jour.year, jour.month, jour.day, 0, premier.debut),
        );
      }
    }
    return const Disponibilite(EtatMedecin.horsHoraires);
  }
}
