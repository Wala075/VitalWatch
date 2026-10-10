import 'package:flutter_test/flutter_test.dart';

import 'package:projet/models/ambulancier.dart';
import 'package:projet/models/infirmier.dart';
import 'package:projet/models/pharmacien.dart';
import 'package:projet/models/utilisateur.dart';

void main() {
  group('Ambulancier (table partagée avec le module Ambulances)', () {
    test('Lecture d\'une ligne du module 3', () {
      final Ambulancier a = Ambulancier.fromMap({
        'id': 1,
        'nom': 'Ali Ben Amor',
        'role': 'conducteur',
        'telephone': '+21698123456',
        'disponible': 1,
        'ambulance_id': 3,
      });
      expect(a.role, RoleAmbulancier.conducteur);
      expect(a.ambulanceId, 3);
      expect(a.initiales, 'AB');
      expect(a.toMap()['role'], 'conducteur');
    });

    test('Fonction inconnue : secouriste par défaut', () {
      expect(RoleAmbulancier.depuisCode('pilote'), RoleAmbulancier.secouriste);
      expect(RoleAmbulancier.depuisCode(null), RoleAmbulancier.secouriste);
    });

    test('Prénom et nom du compte de connexion', () {
      const Ambulancier a = Ambulancier(
        nom: '  Ali   Ben Amor ',
        role: RoleAmbulancier.secouriste,
        telephone: '+21698123456',
      );
      expect(a.prenomNom.prenom, 'Ali');
      expect(a.prenomNom.nom, 'Ben Amor');

      const Ambulancier seul = Ambulancier(
        nom: 'Karim',
        role: RoleAmbulancier.secouriste,
        telephone: '+21698123456',
      );
      expect(seul.prenomNom.prenom, 'Karim');
      expect(seul.prenomNom.nom, '');
    });
  });

  test('Infirmier : aller-retour base de données', () {
    const Infirmier i = Infirmier(
      nom: 'Saidi',
      prenom: 'Rim',
      matricule: 'INF-2001',
      telephone: '+21698765432',
      email: 'infirmier@vitalwatch.tn',
      serviceId: 1,
      disponible: false,
    );
    final Infirmier lu = Infirmier.fromMap({...i.toMap(), 'id': 7});
    expect(lu.id, 7);
    expect(lu.nomComplet, 'Rim Saidi');
    expect(lu.disponible, isFalse);
    expect(lu.serviceId, 1);
  });

  test('Pharmacien : aller-retour et rôle', () {
    const Pharmacien p = Pharmacien(
      nom: 'Mejri',
      prenom: 'Hela',
      matricule: 'PH-3001',
      telephone: '+21698456123',
      email: 'pharmacien@vitalwatch.tn',
    );
    final Pharmacien lu = Pharmacien.fromMap({...p.toMap(), 'id': 1});
    expect(lu.nomComplet, 'Hela Mejri');
    expect(lu.disponible, isTrue);
    expect(Role.pharmacien.libelle, 'Pharmacien');
    expect(Role.pharmacien.accesPersonnel, isFalse);
    expect(Role.admin.gererPersonnel, isTrue);
  });
}
