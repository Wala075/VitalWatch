class Patient {
  static const List<String> groupesSanguins = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  static const Map<String, String> sexes = {'M': 'Homme', 'F': 'Femme'};

  final int? id;
  final String nom;
  final String prenom;
  final String cin;
  final DateTime dateNaissance;
  final String sexe;
  final String telephone;
  final String adresse;
  final String? groupeSanguin;
  final String? email;
  final String? contactUrgenceNom;
  final String? contactUrgenceTel;
  final int? serviceId;
  final int? medecinId;

  const Patient({
    this.id,
    required this.nom,
    required this.prenom,
    required this.cin,
    required this.dateNaissance,
    required this.sexe,
    required this.telephone,
    this.adresse = '',
    this.groupeSanguin,
    this.email,
    this.contactUrgenceNom,
    this.contactUrgenceTel,
    this.serviceId,
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

  /// Copie avec un nouvel id et/ou un médecin affecté.
  Patient copyWith({int? id, int? medecinId}) {
    return Patient(
      id: id ?? this.id,
      nom: nom,
      prenom: prenom,
      cin: cin,
      dateNaissance: dateNaissance,
      sexe: sexe,
      telephone: telephone,
      adresse: adresse,
      groupeSanguin: groupeSanguin,
      email: email,
      contactUrgenceNom: contactUrgenceNom,
      contactUrgenceTel: contactUrgenceTel,
      serviceId: serviceId,
      medecinId: medecinId ?? this.medecinId,
    );
  }

  factory Patient.fromMap(Map<String, Object?> map) {
    return Patient(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      prenom: map['prenom'] as String,
      cin: map['cin'] as String,
      dateNaissance: DateTime.parse(map['date_naissance'] as String),
      sexe: (map['sexe'] as String?) ?? 'M',
      telephone: map['telephone'] as String,
      adresse: (map['adresse'] as String?) ?? '',
      groupeSanguin: map['groupe_sanguin'] as String?,
      email: map['email'] as String?,
      contactUrgenceNom: map['contact_urgence_nom'] as String?,
      contactUrgenceTel: map['contact_urgence_tel'] as String?,
      serviceId: map['service_id'] as int?,
      medecinId: map['medecin_id'] as int?,
    );
  }

  Map<String, Object?> toMap() {
    final String d = dateNaissance.toIso8601String().substring(0, 10);
    return {
      'nom': nom,
      'prenom': prenom,
      'cin': cin,
      'date_naissance': d,
      'sexe': sexe,
      'telephone': telephone,
      'adresse': adresse,
      'groupe_sanguin': groupeSanguin,
      'email': email,
      'contact_urgence_nom': contactUrgenceNom,
      'contact_urgence_tel': contactUrgenceTel,
      'service_id': serviceId,
      'medecin_id': medecinId,
    };
  }
}
