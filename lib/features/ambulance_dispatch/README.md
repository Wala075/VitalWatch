# Module 3 — Ambulances & Interventions

Branche : `feature/ambulances`

## Entités (SQLite, créées par `data/ambulance_schema.dart`)

| Table | Champs |
|---|---|
| `ambulances` | id, immatriculation, type (A/B/C), statut, latitude, longitude, kilometrage |
| `ambulanciers` | id, nom, role, telephone, disponible, ambulance_id (affectation d'équipage) |
| `interventions` | id, ambulance_id, patient_id, alerte_id, adresse, lat, lng, gravite, statut, origine, heure_appel, heure_depart, heure_arrivee, hopital_destination |
| `maintenances` | id, ambulance_id, type, date, cout, prochain_entretien_km, statut |

Les tables sont créées avec `CREATE TABLE IF NOT EXISTS` au premier accès :
`app_database.dart` (fichier commun) n'est pas modifié. Des données de démo
(6 ambulances, 10 ambulanciers, 42 interventions sur 30 jours) sont insérées une fois.

Compte de démo : `ambulancier@vitalwatch.tn` / `ambulancier123`.

## APIs

| API | Usage | Fichier |
|---|---|---|
| flutter_map + OpenStreetMap | cartes (régulation, suivi, choix d'un lieu, heatmap) | `presentation/widgets/carte_osm.dart` |
| OSRM | itinéraire routier + durée → ETA | `data/api/osrm_api.dart` |
| Nominatim | adresse → coordonnées et inverse | `data/api/nominatim_api.dart` |
| Geolocator | position GPS (SOS, ambulancier en mission) | `data/api/geolocalisation_service.dart` |

Sans réseau, OSRM bascule sur une estimation Haversine (ligne droite × 1,3 à 45 km/h).

## Règles métier (`domain/dispatch_manager.dart`)

- **Dispatch automatique** : parmi les ambulances disponibles avec équipage,
  score = distance Haversine × coefficient (type d'ambulance / gravité).
  Critique : C (×1), B (×1,25), A exclu. Urgente : B, C, A. Modérée/faible : A d'abord.
- **Réquisition** : une urgence critique sans ambulance libre récupère l'ambulance
  d'une mission modérée/faible pas encore sur place (remise en file d'attente).
- **File d'attente** par gravité puis ancienneté, traitée dès qu'une ambulance se libère.
- **Création automatique** depuis un SOS (`declencherSos`) ou une alerte vitale
  (`creerDepuisAlerte`), avec anti-doublon par patient.
- **Cycle de vie** : en attente → assignée → en route → sur place → transport → terminée
  (km ajoutés au compteur, ambulance repositionnée à l'hôpital).
- **Maintenance préventive** : blocage automatique si maintenance en cours ou seuil
  `prochain_entretien_km` atteint ; remise en service automatique quand plus rien ne bloque.
- **KPI** : temps moyen de réponse (appel → arrivée), délai de départ, % sous 15 min,
  missions par ambulance, temps par gravité, disponibilité de la flotte, coût maintenance.
- **Heatmap** : interventions regroupées par zones de ~600 m.

## Montre connectée (Mibro C2) → alerte → ambulance

Chaîne : montre → Mibro Fit → Google Fit → **Health Connect** → VitalWatch
(package `health`, Android uniquement, vrai téléphone).

- `data/api/montre_cardiaque_service.dart` : autorisation + lecture du rythme (toutes les minutes).
- `domain/surveillance_cardiaque.dart` : seuils (45–120 bpm par défaut), alerte après
  2 mesures anormales de suite, pause de 15 min après « Je vais bien »,
  gravité critique si ≥ 150 ou ≤ 40 bpm.
- `presentation/screens/surveillance_cardiaque_screen.dart` : courbe 3 h, seuils réglables,
  « Ça va ? » 30 s puis `creerDepuisAlerte` (position GPS) → dispatch automatique.
  Mode démo : « Simuler 2 mesures ».

Accès : icône ❤ dans la barre du module (personnel) ou bouton sous le SOS (patient).

## Intégration module 2 (alertes vitales)

```dart
await DispatchController.instance.creerDepuisAlerte(
  alerteId: alerte.id, // facultatif
  patientId: patient.id,
  position: LatLng(lat, lng),
  gravite: Gravite.critique,
);
```

## Suivi temps réel

`presentation/providers/dispatch_controller.dart` déplace les ambulances le long de
l'itinéraire OSRM (simulation, vitesse réglable ×1 à ×30 dans la barre d'outils),
ou suit la position GPS réelle quand l'ambulancier active « Partager ma position ».

## Tests

`flutter test test/ambulance_dispatch_test.dart test/surveillance_cardiaque_test.dart`
(Haversine, classement du dispatch, immatriculation, hôpital le plus proche,
règles d'alerte cardiaque).
