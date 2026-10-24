import 'rdv_models.dart';

/// Règles métier « pures » (sans base de données) : faciles à tester.
class RdvRegles {
  RdvRegles._();

  /// Un patient ne peut plus annuler lui-même moins de 2 h avant le RDV.
  static const Duration delaiAnnulationPatient = Duration(hours: 2);

  /// Un RDV peut être marqué « absent » 15 min après son heure de début.
  static const Duration toleranceRetard = Duration(minutes: 15);

  /// Nombre de jours explorés pour trouver le prochain créneau libre.
  static const int horizonRechercheJours = 30;

  /// Deux intervalles [a1, a2[ et [b1, b2[ se chevauchent-ils ?
  static bool chevauche(DateTime a1, DateTime a2, DateTime b1, DateTime b2) {
    return a1.isBefore(b2) && b1.isBefore(a2);
  }

  /// Le RDV [debut, debut + duree[ entre-t-il en conflit avec l'un des [occupes] ?
  static RendezVous? conflit(
    DateTime debut,
    int duree,
    List<RendezVous> occupes,
  ) {
    final DateTime fin = debut.add(Duration(minutes: duree));
    for (final RendezVous r in occupes) {
      if (r.statut.estActif && chevauche(debut, fin, r.dateHeure, r.fin)) {
        return r;
      }
    }
    return null;
  }

  /// Le RDV est-il entièrement contenu dans l'un des créneaux du médecin ?
  static Creneau? creneauContenant(
    DateTime debut,
    int duree,
    List<Creneau> creneaux,
  ) {
    final int minDebut = debut.hour * 60 + debut.minute;
    final int minFin = minDebut + duree;
    for (final Creneau c in creneaux) {
      if (c.concerne(debut) && minDebut >= c.heureDebut && minFin <= c.heureFin) {
        return c;
      }
    }
    return null;
  }

  /// Découpe les créneaux du [jour] en horaires de RDV et retire ceux
  /// déjà pris ou déjà passés. Résultat trié.
  static List<DateTime> horairesLibres({
    required DateTime jour,
    required List<Creneau> creneaux,
    required List<RendezVous> occupes,
    required DateTime maintenant,
  }) {
    final Set<DateTime> res = {};
    for (final Creneau c in creneaux) {
      if (!c.concerne(jour) || c.dureeRdv <= 0) {
        continue;
      }
      for (int m = c.heureDebut; m + c.dureeRdv <= c.heureFin; m += c.dureeRdv) {
        final DateTime h = DateTime(jour.year, jour.month, jour.day, m ~/ 60, m % 60);
        if (!h.isAfter(maintenant)) {
          continue;
        }
        if (conflit(h, c.dureeRdv, occupes) == null) {
          res.add(h);
        }
      }
    }
    final List<DateTime> liste = res.toList()..sort();
    return liste;
  }

  /// Durée d'un RDV commençant à [debut] (celle du créneau, 30 min par défaut).
  static int dureePour(DateTime debut, List<Creneau> creneaux) {
    final int minDebut = debut.hour * 60 + debut.minute;
    for (final Creneau c in creneaux) {
      if (c.concerne(debut) && minDebut >= c.heureDebut && minDebut < c.heureFin) {
        return c.dureeRdv;
      }
    }
    return 30;
  }

  /// Deux créneaux d'un même médecin se chevauchent-ils (même jour) ?
  static bool creneauxSeChevauchent(Creneau a, Creneau b) {
    final bool memeJour;
    final DateTime? da = a.date;
    final DateTime? db = b.date;
    if (a.recurrent && b.recurrent) {
      memeJour = a.jour == b.jour;
    } else if (!a.recurrent && !b.recurrent) {
      memeJour = da != null &&
          db != null &&
          da.year == db.year &&
          da.month == db.month &&
          da.day == db.day;
    } else {
      final DateTime? ponctuelle = a.recurrent ? db : da;
      final int jourRecurrent = a.recurrent ? a.jour : b.jour;
      memeJour = ponctuelle != null && ponctuelle.weekday == jourRecurrent;
    }
    return memeJour && a.heureDebut < b.heureFin && b.heureDebut < a.heureFin;
  }

  /// Contrôle de saisie d'un créneau. Renvoie un message d'erreur ou null.
  static String? validerCreneau(Creneau c) {
    if (c.heureFin <= c.heureDebut) {
      return "L'heure de fin doit être après l'heure de début";
    }
    if (c.dureeRdv < 10 || c.dureeRdv > 120) {
      return 'La durée d\'un RDV doit être entre 10 et 120 minutes';
    }
    if (c.heureFin - c.heureDebut < c.dureeRdv) {
      return 'Le créneau est plus court que la durée d\'un RDV';
    }
    if (c.jour < 1 || c.jour > 7) {
      return 'Jour invalide';
    }
    return null;
  }

  /// Priorité calculée à la prise de RDV.
  static PrioriteRdv prioriteInitiale({
    required bool urgent,
    required bool alerteRecente,
  }) {
    if (urgent) {
      return PrioriteRdv.urgente;
    }
    return alerteRecente ? PrioriteRdv.haute : PrioriteRdv.normale;
  }

  /// Tri de la file d'attente : en cours d'abord, puis priorité (une alerte
  /// récente compte comme « haute »), puis heure du RDV.
  static List<RdvDetail> trierFile(List<RdvDetail> liste) {
    int poids(RdvDetail d) {
      int p = d.rdv.priorite.poids;
      if (d.alerteRecente && p < PrioriteRdv.haute.poids) {
        p = PrioriteRdv.haute.poids;
      }
      return p;
    }

    final List<RdvDetail> res = List<RdvDetail>.of(liste);
    res.sort((RdvDetail a, RdvDetail b) {
      final bool aCours = a.rdv.statut == StatutRdv.enCours;
      final bool bCours = b.rdv.statut == StatutRdv.enCours;
      if (aCours != bCours) {
        return aCours ? -1 : 1;
      }
      final int p = poids(b).compareTo(poids(a));
      if (p != 0) {
        return p;
      }
      return a.rdv.dateHeure.compareTo(b.rdv.dateHeure);
    });
    return res;
  }

  /// Le patient peut-il encore annuler lui-même ?
  static bool patientPeutAnnuler(RendezVous r, DateTime maintenant) {
    return r.statut.estActif &&
        r.statut != StatutRdv.enCours &&
        r.dateHeure.difference(maintenant) >= delaiAnnulationPatient;
  }

  /// Le personnel peut-il marquer le patient absent ?
  static bool peutMarquerAbsent(RendezVous r, DateTime maintenant) {
    return (r.statut == StatutRdv.enAttente || r.statut == StatutRdv.confirme) &&
        maintenant.isAfter(r.dateHeure.add(toleranceRetard));
  }

  /// Rappel J-1 / H-1 à afficher pour ce RDV (null si aucun).
  static String? rappelPour(RendezVous r, DateTime maintenant) {
    if (r.statut != StatutRdv.confirme && r.statut != StatutRdv.enAttente) {
      return null;
    }
    final Duration reste = r.dateHeure.difference(maintenant);
    if (reste.isNegative) {
      return null;
    }
    if (reste <= const Duration(hours: 1)) {
      return 'H-1 : votre rendez-vous commence dans ${reste.inMinutes} min';
    }
    if (reste <= const Duration(hours: 24)) {
      return 'J-1 : rendez-vous dans ${reste.inHours} h';
    }
    return null;
  }

  /// Arrondit à la prochaine tranche de 5 minutes (RDV urgents « maintenant »).
  static DateTime prochainesCinqMinutes(DateTime d) {
    final DateTime base = DateTime(d.year, d.month, d.day, d.hour, d.minute);
    final int reste = base.minute % 5;
    return base.add(Duration(minutes: reste == 0 ? 5 : 5 - reste));
  }

  /// Lundi 00:00 de la semaine de [d].
  static DateTime debutSemaine(DateTime d) {
    final DateTime jour = DateTime(d.year, d.month, d.day);
    return jour.subtract(Duration(days: jour.weekday - 1));
  }
}

/// Petits formats d'heure / date du module.
class RdvFormat {
  RdvFormat._();

  static const List<String> joursLongs = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
  ];
  static const List<String> _joursCourts = [
    'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim',
  ];
  static const List<String> _mois = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  static String _deux(int v) => v.toString().padLeft(2, '0');

  /// 570 -> 09:30
  static String minutes(int m) => '${_deux(m ~/ 60)}:${_deux(m % 60)}';

  static String heure(DateTime d) => '${_deux(d.hour)}:${_deux(d.minute)}';

  static String mois(DateTime d) => _mois[d.month - 1];

  /// Mar. 7 oct.
  static String jour(DateTime d) =>
      '${_joursCourts[d.weekday - 1]}. ${d.day} ${_mois[d.month - 1]}';

  /// Mar. 7 oct. · 10:30
  static String complet(DateTime d) => '${jour(d)} · ${heure(d)}';

  /// 07/10/2026 10:30
  static String numerique(DateTime d) =>
      '${_deux(d.day)}/${_deux(d.month)}/${d.year} ${heure(d)}';

  static bool memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
