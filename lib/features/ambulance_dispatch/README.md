# Module 3 — Ambulances & Interventions

Branche : `feature/ambulances`

## Entités (SQLite, créées par `data/ambulance_schema.dart`)

| Table | Champs |
|---|---|
| `ambulances` | id, immatriculation, type (A/B/C), statut, latitude, longitude, kilometrage |
| `ambulanciers` | id, nom, role, telephone, disponible, ambulance_id (affectation d'équipage) |
| `interventions` | id, ambulance_id, patient_id, alerte_id, adresse, lat, lng, gravite, statut, origine, heure_appel, heure_depart, heure_arrivee, hopital_destination |
| `maintenances` | id, ambulance_id, type, date, cout, prochain_entretien_km, statut |
| `mesures_cardiaques` | id, patient_id, bpm, date, source, simulee (montre du patient) |
| `seuils_cardiaques` | patient_id, min, max, modifie_le (fixés par le médecin) |

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

Chaîne : montre → **Bluetooth LE** → VitalWatch (package `flutter_blue_plus`,
Android, vrai téléphone). Plus besoin de Mibro Fit / Google Fit / Health Connect.

Protocole de la montre décodé à partir du journal HCI Bluetooth d'Android
(échanges Mibro Fit ↔ montre) — même famille que la Makibes HR3 de Gadgetbridge :

| Sens | Caractéristique | Paquet | Contenu |
|---|---|---|---|
| téléphone → montre | `6e400002` | `AB 00 0E FF 51 80 00 AA MM JJ hh mm …` | demande des relevés |
| montre → téléphone | `6e400003` | `AB 00 0B FF 51 11 AA MM JJ hh mm BPM …` | relevé cardiaque |
| montre → téléphone | `6e400003` | `AB 00 16 FF 51 20 …` | résumé horaire (pas) |
| montre → téléphone | `6e400003` | `AB 00 05 FF 91 80 charge niveau` | batterie |
| téléphone ↔ montre | `2a24` / `2a26` | service standard « Device Information » | modèle / firmware |

Tableau de bord de la montre (écran ❤) : batterie (% + en charge, alerte ≤ 15 %),
signal Bluetooth (RSSI), pas et calories du jour, rythme moyen / min / max du jour,
modèle + firmware, heure de la dernière synchro.

La montre mesure seule toutes les 5 min (et à chaque mesure lancée sur la montre) ;
VitalWatch lui redemande ses relevés toutes les 30 secondes.

- `data/api/mibro_protocole.dart` : commandes, décodage des paquets, réassemblage (testé).
- `data/api/montre_ble_service.dart` : recherche de la montre (déjà connectée à Mibro Fit,
  appairée ou scan « XPAW… »), connexion, lecture des relevés.
- `data/api/montre_cardiaque_service.dart` : ancienne lecture via Health Connect (non utilisée).
- `domain/surveillance_cardiaque.dart` : seuils (45–120 bpm par défaut), alerte après
  2 mesures anormales de suite, pause de 15 min après « Je vais bien »,
  gravité critique si ≥ 150 ou ≤ 40 bpm. Quand on change un seuil (n'importe
  lequel), la pause est levée et la dernière mesure (< 30 min) est comparée tout
  de suite : hors seuils → « Ça va ? », sinon un message explique pourquoi.
- `presentation/screens/surveillance_cardiaque_screen.dart` : courbe 3 h, seuils réglables,
  « Ça va ? » 30 s puis `creerDepuisAlerte` (position GPS) → dispatch automatique.
  Mode démo : « Simuler 2 mesures ».

Accès : bouton « Surveiller mon rythme cardiaque » sous le SOS, **compte patient
uniquement** (c'est le patient qui porte la montre).

### Synchronisation patient → personnel

La montre n'est connectée qu'au téléphone du patient. Toutes les 30 s, ce téléphone
enregistre les nouvelles mesures dans la base (table `mesures_cardiaques`, doublons
ignorés) et relit ses seuils (table `seuils_cardiaques`). Le personnel lit ces tables,
sans jamais se connecter à la montre :

| Compte | Ce qu'il voit / fait |
|---|---|
| Patient | montre en Bluetooth, courbe, « Ça va ? », SOS, « help » ; seuils en lecture seule |
| Médecin | icône ❤ du module : ses patients (ou tous), dernier rythme, alertes, courbe 3 h, stats du jour ; **fixe les seuils** de chaque patient |
| Admin / infirmier | même suivi (l'admin peut aussi fixer les seuils) |
| Ambulancier | carte « Rythme du patient » dans *Ma mission* et dans l'intervention |

Seuils changés par le médecin → appliqués par le téléphone du patient à la synchro
suivante : si la dernière mesure est hors seuils, « Ça va ? » puis ambulance.

- `data/rythme_repository.dart` : enregistrement, historique, seuils, tableau de suivi.
- `domain/suivi_cardiaque.dart` : résumé par patient (actif, en alerte), tri, statistiques (testé).
- `presentation/screens/suivi_cardiaque_screen.dart` : liste + détail patient (personnel).
- `presentation/widgets/rythme_patient.dart` : carte « Rythme du patient » d'une mission.

Base SQLite locale : la synchronisation fonctionne entre les comptes d'un même
téléphone (démo). Pour plusieurs téléphones, il faudra un serveur commun
(ex. Firebase) — même schéma de tables.

## Alerte vocale (« help », « au secours »)

Package `speech_to_text` (reconnaissance vocale du téléphone, permission micro
`RECORD_AUDIO`). Tant que l'écran SOS ou Surveillance cardiaque est ouvert et
l'application au premier plan, le téléphone écoute en continu (relance
automatique après chaque silence, coupure en arrière-plan).

- `domain/appel_aide.dart` : détection des mots-clés (help, au secours, à l'aide,
  aidez-moi, besoin d'aide, SOS…), insensible à la casse, aux accents et à la
  ponctuation, mots entiers uniquement (testé).
- `data/api/ecoute_vocale_service.dart` : écoute continue, un seul micro partagé
  entre les écrans (le dernier ouvert reçoit l'appel).
- `presentation/widgets/ecoute_vocale.dart` : carte « Alerte vocale » (interrupteur,
  état, dernière phrase entendue) + compte à rebours de **10 s** pour annuler.
- Puis : SOS (`declencherSos`, position démo si pas de GPS) ou, depuis la
  surveillance cardiaque, `creerDepuisAlerte` (urgente, critique si le dernier
  rythme est ≥ 150 ou ≤ 40 bpm).

Espace patient : l'écoute marche **dans toute l'application** (accueil, planning…),
pas seulement sur l'écran SOS (onglet « SOS » de la barre du bas).

**Même écran verrouillé** (interrupteur de la carte, Android) : `flutter_foreground_task`
démarre un service de premier plan (types `microphone|location`, notification fixe) qui
garde l'application active. « help » entendu → notification « Appel à l'aide détecté ·
ambulance dans 10 s » avec un bouton **Annuler** ; sans réponse, SOS envoyé (GPS, ou
position de démo). Choix mémorisé (`data/api/protection_vocale_service.dart`).
Ne pas fermer l'application depuis les applications récentes (l'écoute s'arrêterait).

Android émet un petit bip à chaque relance de l'écoute (comportement du système).

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

`flutter test test/ambulance_dispatch_test.dart test/surveillance_cardiaque_test.dart test/mibro_protocole_test.dart test/appel_aide_test.dart test/suivi_cardiaque_test.dart`
(Haversine, classement du dispatch, immatriculation, hôpital le plus proche,
règles d'alerte cardiaque, décodage des paquets de la montre, mots d'appel à l'aide,
suivi cardiaque des patients).
