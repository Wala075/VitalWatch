/// Service hospitalier (Cardiologie, Urgences...).
class Service {
  final int? id;
  final String nom;
  final int? chefServiceId;
  final int? etage;
  final String telephone;
  final int capacite;

  const Service({
    this.id,
    required this.nom,
    this.chefServiceId,
    this.etage,
    required this.telephone,
    required this.capacite,
  });

  factory Service.fromMap(Map<String, Object?> map) {
    return Service(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      chefServiceId: map['chef_service_id'] as int?,
      etage: map['etage'] as int?,
      telephone: (map['telephone'] as String?) ?? '',
      capacite: (map['capacite'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'nom': nom,
      'chef_service_id': chefServiceId,
      'etage': etage,
      'telephone': telephone,
      'capacite': capacite,
    };
  }
}
