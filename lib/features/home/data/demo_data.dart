import 'package:flutter/material.dart';

// Données FICTIVES de démonstration de l'espace santé.
// À remplacer plus tard par les vraies données des modules
// (médecins : module 1, rendez-vous : module 4, constantes : module 2).

class Specialite {
  const Specialite(this.nom, this.icon, this.couleur);

  final String nom;
  final IconData icon;
  final Color couleur;
}

class DemoDoctor {
  const DemoDoctor({
    required this.id,
    required this.prenom,
    required this.nom,
    required this.specialite,
    required this.categorie,
    required this.hopital,
    required this.note,
    required this.avis,
    required this.experience,
    required this.patients,
    required this.prix,
    required this.apropos,
    required this.couleur,
    this.enLigne = true,
  });

  final int id;
  final String prenom;
  final String nom;
  final String specialite;
  final String categorie;
  final String hopital;
  final double note;
  final int avis;
  final int experience;
  final String patients;
  final int prix;
  final String apropos;
  final Color couleur;
  final bool enLigne;

  String get nomComplet => 'Dr $prenom $nom';

  String get initiales => '${prenom[0]}${nom[0]}'.toUpperCase();
}

enum StatutRdv { aVenir, termine, annule }

class DemoRdv {
  DemoRdv({
    required this.id,
    required this.medecin,
    required this.date,
    this.statut = StatutRdv.aVenir,
  });

  final int id;
  final DemoDoctor medecin;
  final DateTime date;
  StatutRdv statut;

  /// Un RDV « à venir » dont la date est passée est considéré terminé.
  StatutRdv get statutEffectif {
    if (statut == StatutRdv.aVenir && date.isBefore(DateTime.now())) {
      return StatutRdv.termine;
    }
    return statut;
  }
}

class Astuce {
  const Astuce(this.titre, this.texte, this.icon);

  final String titre;
  final String texte;
  final IconData icon;
}

class DemoData {
  DemoData._();

  static const List<Specialite> specialites = [
    Specialite('Général', Icons.medical_services_rounded, Color(0xFF2E9E6A)),
    Specialite('Cœur', Icons.favorite_rounded, Color(0xFFE5484D)),
    Specialite('Cerveau', Icons.psychology_rounded, Color(0xFF7C5CC4)),
    Specialite('Dentaire', Icons.sentiment_satisfied_alt_rounded, Color(0xFF3BA776)),
    Specialite('Yeux', Icons.visibility_rounded, Color(0xFF2B8FB3)),
    Specialite('Enfants', Icons.child_care_rounded, Color(0xFFF5A524)),
  ];

  static const List<DemoDoctor> medecins = [
    DemoDoctor(
      id: 1,
      prenom: 'Sarra',
      nom: 'Ben Ali',
      specialite: 'Cardiologue',
      categorie: 'Cœur',
      hopital: 'Clinique Les Oliviers, Sousse',
      note: 4.9,
      avis: 1280,
      experience: 12,
      patients: '2.9k',
      prix: 60,
      apropos: 'Spécialiste du rythme cardiaque et de l\'hypertension. '
          'Elle mise sur la prévention et explique chaque résultat simplement.',
      couleur: Color(0xFFF2B8AE),
    ),
    DemoDoctor(
      id: 2,
      prenom: 'Mehdi',
      nom: 'Trabelsi',
      specialite: 'Neurologue',
      categorie: 'Cerveau',
      hopital: 'Hôpital Sahloul, Sousse',
      note: 4.8,
      avis: 865,
      experience: 15,
      patients: '2.9k',
      prix: 75,
      apropos: 'Prise en charge des migraines, des troubles du sommeil et des '
          'douleurs nerveuses. Consultations calmes, sans précipitation.',
      couleur: Color(0xFFCDBDF2),
    ),
    DemoDoctor(
      id: 3,
      prenom: 'Yasmine',
      nom: 'Khelifi',
      specialite: 'Dentiste',
      categorie: 'Dentaire',
      hopital: 'Cabinet dentaire Corniche, Sousse',
      note: 4.7,
      avis: 760,
      experience: 8,
      patients: '1.8k',
      prix: 40,
      apropos: 'Soins dentaires, détartrage et blanchiment. '
          'Une approche douce, idéale pour les patients anxieux.',
      couleur: Color(0xFFB7E3CC),
    ),
    DemoDoctor(
      id: 4,
      prenom: 'Anis',
      nom: 'Jaziri',
      specialite: 'Pédiatre',
      categorie: 'Enfants',
      hopital: 'Hôpital Farhat Hached, Sousse',
      note: 4.9,
      avis: 1120,
      experience: 10,
      patients: '3.1k',
      prix: 45,
      apropos: 'Suivi de la croissance, vaccins et maladies de l\'enfant. '
          'Très patient avec les plus petits.',
      couleur: Color(0xFFF9D3A5),
    ),
    DemoDoctor(
      id: 5,
      prenom: 'Karim',
      nom: 'Mansour',
      specialite: 'Ophtalmologue',
      categorie: 'Yeux',
      hopital: 'Centre Vision Plus, Monastir',
      note: 4.8,
      avis: 930,
      experience: 14,
      patients: '2.6k',
      prix: 65,
      apropos: 'Examens de la vue, correction visuelle et soins de la fatigue '
          'oculaire liée aux écrans, pour tous les âges.',
      couleur: Color(0xFFB9DDF0),
    ),
    DemoDoctor(
      id: 6,
      prenom: 'Ines',
      nom: 'Gharbi',
      specialite: 'Médecin généraliste',
      categorie: 'Général',
      hopital: 'Polyclinique Ennour, Sousse',
      note: 4.8,
      avis: 1100,
      experience: 9,
      patients: '3.4k',
      prix: 35,
      apropos: 'Bilans de santé, suivi des maladies chroniques et conseils '
          'de prévention pour toute la famille.',
      couleur: Color(0xFFCBE7B8),
    ),
    DemoDoctor(
      id: 7,
      prenom: 'Omar',
      nom: 'Hammami',
      specialite: 'Médecin généraliste',
      categorie: 'Général',
      hopital: 'Cabinet médical Khezama, Sousse',
      note: 4.6,
      avis: 410,
      experience: 6,
      patients: '1.2k',
      prix: 30,
      apropos: 'Consultations de médecine générale, certificats médicaux et '
          'renouvellement d\'ordonnances.',
      couleur: Color(0xFFE6D3F5),
      enLigne: false,
    ),
  ];

  static const List<Astuce> astuces = [
    Astuce(
      'Buvez de l\'eau dès le réveil',
      'Un grand verre d\'eau au réveil relance votre organisme.',
      Icons.water_drop_rounded,
    ),
    Astuce(
      'Levez-vous toutes les heures',
      'Deux minutes de marche soulagent le dos et relancent la concentration.',
      Icons.directions_walk_rounded,
    ),
    Astuce(
      'Couchez-vous avant 23 h',
      'Un sommeil régulier aide à mieux contrôler la tension.',
      Icons.bedtime_rounded,
    ),
  ];

  /// Pas de la semaine (en milliers), du lundi au dimanche.
  static const List<double> pasSemaine = [5.2, 6.8, 4.9, 9.1, 7.2, 3.8, 6.5];

  static const List<String> joursSemaine = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
}

/// Petits formats de date en français (sans dépendance).
class DateFr {
  DateFr._();

  static const List<String> _joursCourts = [
    'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim',
  ];
  static const List<String> _joursLongs = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
  ];
  static const List<String> _mois = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  static String jourCourt(DateTime d) => _joursCourts[d.weekday - 1];

  static String jourLong(DateTime d) => _joursLongs[d.weekday - 1];

  static String mois(DateTime d) => _mois[d.month - 1];

  static String heure(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String complet(DateTime d) =>
      '${jourCourt(d)}. ${d.day} ${mois(d)} · ${heure(d)}';
}
