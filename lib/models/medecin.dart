class Medecin {
  final int? id;
  final String nom;
  final String prenom;
  final String matricule;
  final String specialite;
  final String telephone;
  final String email;
  final String? photo;
  final int? serviceId;
  final bool disponible;

  const Medecin({
    this.id,
    required this.nom,
    required this.prenom,
    required this.matricule,
    required this.specialite,
    required this.telephone,
    required this.email,
    this.photo,
    this.serviceId,
    this.disponible = true,
  });

  String get nomComplet => 'Dr $prenom $nom';

  factory Medecin.fromMap(Map<String, Object?> map) {
    return Medecin(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      prenom: map['prenom'] as String,
      matricule: map['matricule'] as String,
      specialite: map['specialite'] as String,
      telephone: map['telephone'] as String,
      email: map['email'] as String,
      photo: map['photo'] as String?,
      serviceId: map['service_id'] as int?,
      disponible: ((map['disponible'] as int?) ?? 1) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'nom': nom,
      'prenom': prenom,
      'matricule': matricule,
      'specialite': specialite,
      'telephone': telephone,
      'email': email,
      'photo': photo,
      'service_id': serviceId,
      'disponible': disponible ? 1 : 0,
    };
  }
}
