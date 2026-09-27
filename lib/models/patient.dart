class Patient {
  final String id;
  final String cin;
  final String nom;
  final String prenom;
  final DateTime dateNaissance;
  final String telephone;
  final String adresse;
  final String? groupeSanguin;
  final String? medecinId;

  const Patient({
    required this.id,
    required this.cin,
    required this.nom,
    required this.prenom,
    required this.dateNaissance,
    required this.telephone,
    required this.adresse,
    this.groupeSanguin,
    this.medecinId,
  });

  String get nomComplet => '$prenom $nom';

  int get age {
    final DateTime now = DateTime.now();
    int a = now.year - dateNaissance.year;
    if (now.month < dateNaissance.month ||
        (now.month == dateNaissance.month && now.day < dateNaissance.day)) {
      a--;
    }
    return a;
  }

  factory Patient.fromMap(String id, Map<String, dynamic> map) {
    return Patient(
      id: id,
      cin: map['cin'] ?? '',
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      dateNaissance:
          DateTime.tryParse(map['dateNaissance'] ?? '') ?? DateTime(2000),
      telephone: map['telephone'] ?? '',
      adresse: map['adresse'] ?? '',
      groupeSanguin: map['groupeSanguin'],
      medecinId: map['medecinId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cin': cin,
      'nom': nom,
      'prenom': prenom,
      'dateNaissance': dateNaissance.toIso8601String(),
      'telephone': telephone,
      'adresse': adresse,
      'groupeSanguin': groupeSanguin,
      'medecinId': medecinId,
    };
  }
}
