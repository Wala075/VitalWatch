enum Role { admin, medecin, infirmier, ambulancier, patient }

class Utilisateur {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final Role role;

  const Utilisateur({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.role,
  });

  String get nomComplet => '$prenom $nom';

  factory Utilisateur.fromMap(String id, Map<String, dynamic> map) {
    return Utilisateur(
      id: id,
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      email: map['email'] ?? '',
      telephone: map['telephone'] ?? '',
      role: Role.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => Role.patient,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'role': role.name,
    };
  }
}
