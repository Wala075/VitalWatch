enum RoleAmbulancier {
  conducteur('conducteur', 'Ambulancier conducteur'),
  secouriste('secouriste', 'Secouriste'),
  infirmier('infirmier', 'Infirmier urgentiste'),
  medecin('medecin', 'Médecin urgentiste');

  const RoleAmbulancier(this.code, this.libelle);

  final String code;
  final String libelle;

  static RoleAmbulancier depuisCode(String? code) {
    for (final RoleAmbulancier r in RoleAmbulancier.values) {
      if (r.code == code) {
        return r;
      }
    }
    return RoleAmbulancier.secouriste;
  }
}

/// Membre d'équipage. [ambulanceId] : ambulance à laquelle il est affecté.
class Ambulancier {
  final int? id;
  final String nom;
  final RoleAmbulancier role;
  final String telephone;
  final bool disponible;
  final int? ambulanceId;

  const Ambulancier({
    this.id,
    required this.nom,
    required this.role,
    required this.telephone,
    this.disponible = true,
    this.ambulanceId,
  });

  String get initiales {
    final List<String> mots = nom.trim().split(' ');
    String res = '';
    for (final String m in mots) {
      if (m.isNotEmpty && res.length < 2) {
        res += m[0].toUpperCase();
      }
    }
    return res.isEmpty ? '?' : res;
  }

  factory Ambulancier.fromMap(Map<String, Object?> map) {
    return Ambulancier(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      role: RoleAmbulancier.depuisCode(map['role'] as String?),
      telephone: (map['telephone'] as String?) ?? '',
      disponible: ((map['disponible'] as int?) ?? 1) == 1,
      ambulanceId: map['ambulance_id'] as int?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'nom': nom,
      'role': role.code,
      'telephone': telephone,
      'disponible': disponible ? 1 : 0,
      'ambulance_id': ambulanceId,
    };
  }
}
