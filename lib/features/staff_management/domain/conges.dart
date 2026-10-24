import '../../../models/utilisateur.dart';

enum TypeConge {
  annuel('annuel', 'Congé annuel'),
  maladie('maladie', 'Congé maladie'),
  formation('formation', 'Formation'),
  exceptionnel('exceptionnel', 'Congé exceptionnel');

  const TypeConge(this.code, this.libelle);

  final String code;
  final String libelle;

  static TypeConge depuisCode(String? code) {
    for (final TypeConge t in TypeConge.values) {
      if (t.code == code) return t;
    }
    return TypeConge.annuel;
  }
}

enum StatutConge {
  enAttente('en_attente', 'En attente'),
  validee('validee', 'Validé'),
  refusee('refusee', 'Refusé'),
  annulee('annulee', 'Annulé');

  const StatutConge(this.code, this.libelle);

  final String code;
  final String libelle;

  static StatutConge depuisCode(String? code) {
    for (final StatutConge s in StatutConge.values) {
      if (s.code == code) return s;
    }
    return StatutConge.enAttente;
  }
}

/// Demande de congé d'un médecin ou d'un infirmier (table `conges`).
/// [debut] et [fin] sont des jours entiers, fin incluse.
class Conge {
  const Conge({
    this.id,
    required this.role,
    required this.demandeurId,
    required this.debut,
    required this.fin,
    required this.type,
    this.motif = '',
    this.statut = StatutConge.enAttente,
    this.commentaire,
  });

  final int? id;

  /// Role.medecin ou Role.infirmier.
  final Role role;
  final int demandeurId;
  final DateTime debut;
  final DateTime fin;
  final TypeConge type;
  final String motif;
  final StatutConge statut;

  /// Explication d'un refus (admin ou refus automatique).
  final String? commentaire;

  int get nbJours => RegleConges.nbJours(debut, fin);

  factory Conge.fromMap(Map<String, Object?> map) {
    final String role = map['demandeur_role'] as String;
    return Conge(
      id: map['id'] as int?,
      role: role == Role.infirmier.name ? Role.infirmier : Role.medecin,
      demandeurId: map['demandeur_id'] as int,
      debut: DateTime.parse(map['date_debut'] as String),
      fin: DateTime.parse(map['date_fin'] as String),
      type: TypeConge.depuisCode(map['type'] as String?),
      motif: (map['motif'] as String?) ?? '',
      statut: StatutConge.depuisCode(map['statut'] as String?),
      commentaire: map['commentaire'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'demandeur_role': role.name,
      'demandeur_id': demandeurId,
      'date_debut': RegleConges.iso(debut),
      'date_fin': RegleConges.iso(fin),
      'type': type.code,
      'motif': motif,
      'statut': statut.code,
      'commentaire': commentaire,
    };
  }
}

/// Collègue du même service (pour la règle d'effectif minimum) :
/// sa disponibilité et ses congés validés.
class Collegue {
  const Collegue({required this.disponible, this.conges = const []});

  final bool disponible;
  final List<(DateTime, DateTime)> conges;
}

/// Règles métier des congés (fonctions pures, testées).
class RegleConges {
  RegleConges._();

  /// Jours de congé annuel par année civile.
  static const int soldeAnnuel = 30;

  /// Durée maximale d'une demande.
  static const int dureeMax = 90;

  /// À partir de cette durée, les patients d'un médecin sont confiés
  /// à un collègue du service pendant son absence.
  static const int seuilReaffectation = 7;

  /// Personnes du même rôle qui doivent rester présentes dans le service.
  static const int effectifMinimum = 1;

  static DateTime jour(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// 2026-11-03
  static String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Nombre de jours, fin incluse.
  static int nbJours(DateTime debut, DateTime fin) =>
      jour(fin).difference(jour(debut)).inDays + 1;

  static bool chevauchent(DateTime a1, DateTime a2, DateTime b1, DateTime b2) =>
      !jour(a1).isAfter(jour(b2)) && !jour(b1).isAfter(jour(a2));

  static bool couvre(DateTime debut, DateTime fin, DateTime d) =>
      chevauchent(debut, fin, d, d);

  /// Jours par année civile (une demande peut chevaucher deux années).
  static Map<int, int> joursParAnnee(DateTime debut, DateTime fin) {
    final Map<int, int> res = {};
    for (DateTime d = jour(debut);
        !d.isAfter(jour(fin));
        d = d.add(const Duration(days: 1))) {
      res[d.year] = (res[d.year] ?? 0) + 1;
    }
    return res;
  }

  /// Dates cohérentes : pas dans le passé, fin après début, durée maximale.
  static String? verifierDates(DateTime debut, DateTime fin, DateTime aujourdHui) {
    if (jour(debut).isBefore(jour(aujourdHui))) {
      return 'Le congé ne peut pas commencer dans le passé';
    }
    if (jour(fin).isBefore(jour(debut))) {
      return 'La date de fin doit être après la date de début';
    }
    if (nbJours(debut, fin) > dureeMax) {
      return 'Une demande ne peut pas dépasser $dureeMax jours';
    }
    return null;
  }

  /// Solde annuel : [dejaPris] = jours de congé annuel déjà validés ou
  /// demandés, par année. Renvoie un message si le solde est dépassé.
  static String? verifierSolde(
    DateTime debut,
    DateTime fin,
    Map<int, int> dejaPris,
  ) {
    final Map<int, int> demande = joursParAnnee(debut, fin);
    for (final MapEntry<int, int> e in demande.entries) {
      final int pris = dejaPris[e.key] ?? 0;
      if (pris + e.value > soldeAnnuel) {
        final int reste = soldeAnnuel - pris;
        return 'Solde de congé annuel ${e.key} insuffisant : '
            '${reste < 0 ? 0 : reste} jour(s) restant(s), ${e.value} demandé(s)';
      }
    }
    return null;
  }

  /// Jours de [debut]–[fin] où il resterait moins de [minimum] collègues
  /// présents (disponibles et pas en congé validé).
  static List<DateTime> joursEnSousEffectif({
    required DateTime debut,
    required DateTime fin,
    required List<Collegue> collegues,
    int minimum = effectifMinimum,
  }) {
    final List<DateTime> res = [];
    for (DateTime d = jour(debut);
        !d.isAfter(jour(fin));
        d = d.add(const Duration(days: 1))) {
      int presents = 0;
      for (final Collegue c in collegues) {
        if (!c.disponible) continue;
        bool absent = false;
        for (final (DateTime, DateTime) p in c.conges) {
          if (couvre(p.$1, p.$2, d)) {
            absent = true;
            break;
          }
        }
        if (!absent) presents++;
      }
      if (presents < minimum) res.add(d);
    }
    return res;
  }

  /// « 03/11, 04/11, 05/11 et 2 autres »
  static String resumerJours(List<DateTime> jours, {int max = 3}) {
    String f(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    final List<String> premiers = [for (final DateTime d in jours.take(max)) f(d)];
    final int reste = jours.length - premiers.length;
    return reste > 0 ? '${premiers.join(', ')} et $reste autre(s)' : premiers.join(', ');
  }
}

/// Demande + nom du demandeur et son service (affichage).
class CongeDetail {
  const CongeDetail({
    required this.conge,
    this.nom,
    this.serviceId,
    this.serviceNom,
  });

  final Conge conge;

  /// null si la personne a été supprimée.
  final String? nom;
  final int? serviceId;
  final String? serviceNom;
}

/// Résultat de la validation par l'admin.
class ResultatConge {
  const ResultatConge({required this.validee, required this.message});

  /// false : refus automatique (effectif minimum).
  final bool validee;
  final String message;
}
