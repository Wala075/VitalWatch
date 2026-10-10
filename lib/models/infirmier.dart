/// Infirmier(ère) d'un service hospitalier (module 1).
class Infirmier {
  final int? id;
  final String nom;
  final String prenom;
  final String matricule;
  final String telephone;
  final String email;
  final int? serviceId;
  final bool disponible;

  const Infirmier({
    this.id,
    required this.nom,
    required this.prenom,
    required this.matricule,
    required this.telephone,
    required this.email,
    this.serviceId,
    this.disponible = true,
  });

  String get nomComplet => '$prenom $nom';

  factory Infirmier.fromMap(Map<String, Object?> map) {
    return Infirmier(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      prenom: map['prenom'] as String,
      matricule: map['matricule'] as String,
      telephone: map['telephone'] as String,
      email: map['email'] as String,
      serviceId: map['service_id'] as int?,
      disponible: ((map['disponible'] as int?) ?? 1) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'nom': nom,
      'prenom': prenom,
      'matricule': matricule,
      'telephone': telephone,
      'email': email,
      'service_id': serviceId,
      'disponible': disponible ? 1 : 0,
    };
  }
}
