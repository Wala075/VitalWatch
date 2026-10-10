enum Role { admin, medecin, infirmier, ambulancier, patient, pharmacien }

/// Compte de connexion. [refId] pointe vers le médecin ou le patient lié.
class Utilisateur {
  final int? id;
  final String email;
  final String motDePasseHash;
  final Role role;
  final int? refId;
  final String nom;
  final String prenom;
  final bool actif;

  const Utilisateur({
    this.id,
    required this.email,
    required this.motDePasseHash,
    required this.role,
    this.refId,
    this.nom = '',
    this.prenom = '',
    this.actif = true,
  });

  String get nomComplet => '$prenom $nom'.trim();

  factory Utilisateur.fromMap(Map<String, Object?> map) {
    final Object? role = map['role'];
    return Utilisateur(
      id: map['id'] as int?,
      email: map['email'] as String,
      motDePasseHash: map['mot_de_passe_hash'] as String,
      role: Role.values.firstWhere(
        (r) => r.name == role,
        orElse: () => Role.patient,
      ),
      refId: map['ref_id'] as int?,
      nom: (map['nom'] as String?) ?? '',
      prenom: (map['prenom'] as String?) ?? '',
      actif: ((map['actif'] as int?) ?? 1) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'email': email,
      'mot_de_passe_hash': motDePasseHash,
      'role': role.name,
      'ref_id': refId,
      'nom': nom,
      'prenom': prenom,
      'actif': actif ? 1 : 0,
    };
  }
}

extension RoleLibelle on Role {
  String get libelle {
    switch (this) {
      case Role.admin:
        return 'Administrateur';
      case Role.medecin:
        return 'Médecin';
      case Role.infirmier:
        return 'Infirmier';
      case Role.ambulancier:
        return 'Ambulancier';
      case Role.patient:
        return 'Patient';
      case Role.pharmacien:
        return 'Pharmacien';
    }
  }
}

/// Rôles et permissions par profil.
extension RolePermissions on Role {
  /// Accès au module Services & Personnel.
  bool get accesPersonnel =>
      this == Role.admin || this == Role.medecin || this == Role.infirmier;

  bool get gererServices => this == Role.admin;

  bool get gererMedecins => this == Role.admin;

  /// Ajouter / modifier / supprimer infirmiers, ambulanciers et pharmaciens
  /// (+ comptes).
  bool get gererPersonnel => this == Role.admin;

  bool get gererPatients =>
      this == Role.admin || this == Role.medecin || this == Role.infirmier;

  bool get supprimerPatients => this == Role.admin;

  bool get voirStats => this == Role.admin || this == Role.medecin;
}
