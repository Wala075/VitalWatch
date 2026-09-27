class Medecin {
  final String id;
  final String nom;
  final String prenom;
  final String specialite;
  final String telephone;
  final String email;
  final String? serviceId;

  const Medecin({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.specialite,
    required this.telephone,
    required this.email,
    this.serviceId,
  });

  String get nomComplet => 'Dr $prenom $nom';

  factory Medecin.fromMap(String id, Map<String, dynamic> map) {
    return Medecin(
      id: id,
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      specialite: map['specialite'] ?? '',
      telephone: map['telephone'] ?? '',
      email: map['email'] ?? '',
      serviceId: map['serviceId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'prenom': prenom,
      'specialite': specialite,
      'telephone': telephone,
      'email': email,
      'serviceId': serviceId,
    };
  }
}
