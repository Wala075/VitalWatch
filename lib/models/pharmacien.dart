/// Pharmacien(ne) de l'hôpital (module 1). La délivrance des ordonnances
/// se fait dans le module 5 (Ordonnances & Assurance).
class Pharmacien {
  final int? id;
  final String nom;
  final String prenom;
  final String matricule;
  final String telephone;
  final String email;
  final bool disponible;

  const Pharmacien({
    this.id,
    required this.nom,
    required this.prenom,
    required this.matricule,
    required this.telephone,
    required this.email,
    this.disponible = true,
  });

  String get nomComplet => '$prenom $nom';

  factory Pharmacien.fromMap(Map<String, Object?> map) {
    return Pharmacien(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      prenom: map['prenom'] as String,
      matricule: map['matricule'] as String,
      telephone: map['telephone'] as String,
      email: map['email'] as String,
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
      'disponible': disponible ? 1 : 0,
    };
  }
}
