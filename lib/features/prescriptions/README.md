# Module 5 — Ordonnances & Assurance

Branche : `feature/ordonnances` · Responsable : Hamza Mrayhi

Circuit complet d'un médicament prescrit : ordonnance, délivrance, prise du
traitement, remboursement CNAM / mutuelle et paiement du reste à charge.

## Avancement

| Étape | Contenu | État |
|---|---|---|
| 1 | Tables, déclencheurs, modèles, repositories, données de test | fait |
| 2 | Écrans admin : catalogue, assurances, taux, APCI | fait |
| 3 | Ordonnances côté médecin (cycle de vie, boîtes, verrouillage) | fait |
| 4 | Délivrance (pharmacien), planning des prises, observance, fin de stock, renouvellement | fait |
| 5 | Prise en charge, simulateur, dossiers, service CNAM simulé, plafond, relances | fait |
| 6 | API RxNorm (génériques) et Konnect (paiement du reste à charge) | fait |
| 7 | PDF + QR code, scan anti-fraude | fait |
| 8 | Statistiques | fait |
| 9 | Onglet fiche patient et `traitementsActifs` pour la gestion Patients | fait |

## Base de données (`data/prescriptions_schema.dart`)

Tables créées avec `CREATE TABLE IF NOT EXISTS` au démarrage
(`PrescriptionsSchema.initialiserAuDemarrage()` dans `main.dart`), comme le
module 3 : `app_database.dart` n'est pas modifié.

| Table | Rôle | Liée à |
|---|---|---|
| `medicament` | Catalogue : DCI, forme, dosage, prix, catégorie | — |
| `ordonnance` | Document daté, validité, statut, signature | `patients`, `medecins`, `ordonnance` |
| `ligne_ordonnance` | Médicament, posologie, durée, boîtes | `ordonnance`, `medicament` |
| `prise` | Prise prévue et son suivi | `ligne_ordonnance` |
| `assurance` | CNAM, mutuelle, assurance privée | — |
| `taux_couverture` | Taux par catégorie (`tous` pour une mutuelle) | `assurance` |
| `apci` | Code CIM-10 → maladie prise en charge à 100 % | — |
| `contrat_assurance` | Couverture d'un patient | `patients`, `assurance`, `apci` |
| `dossier_remboursement` | Demande de remboursement | `ordonnance`, `contrat_assurance` |
| `prescriptions_meta` | Drapeaux internes du module (données de démo déjà créées…) | — |

Écarts avec le cahier des charges, imposés par le dépôt :

- `ordonnance.medecin_id` → `medecins(id)` (le compte connecté y pointe via `utilisateurs.ref_id`) ;
- `consultation_id` sans clé étrangère tant que la table du module Rendez-vous n'existe pas ;
- `patient_id` en `ON DELETE RESTRICT` : un patient qui a une ordonnance ou un contrat
  ne peut pas être supprimé (à afficher proprement côté Services).

Déclencheurs (refus directement dans la base) :

| Déclencheur | Refuse |
|---|---|
| `trg_ordonnance_suppression` | supprimer une ordonnance validée |
| `trg_ligne_verrou` | modifier une ligne d'une ordonnance validée (seule `quantite_delivree` avance) |
| `trg_ligne_ajout_verrou` | ajouter une ligne à une ordonnance validée |
| `trg_ligne_suppression_verrou` | supprimer une ligne d'une ordonnance validée |
| `trg_ordonnance_verrou` | modifier l'en-tête d'une ordonnance validée ou la remettre en brouillon |

Dates : `2026-10-09` pour les dates, `2026-10-09 08:00:00` (heure locale) pour les
heures, même format que `datetime()` de SQLite.

## Écrans (`presentation/`)

`PrescriptionsScreen` : onglets selon le profil, barre flottante de l'accueil.
Sur l'accueil, le patient a une carte « Mon traitement » (prochaine prise,
observance, alertes) qui ouvre le module (`home_tab.dart`, fichier commun).

| Profil | Onglets |
|---|---|
| Patient | Aujourd'hui · Ordonnances · Remboursements |
| Médecin | Ordonnances · Catalogue · Stats (les siennes) |
| Pharmacien | Délivrance · Catalogue |
| Infirmier | Patients (lecture) · Catalogue |
| Admin | Catalogue · Assurances · APCI · Patients · Dossiers · Stats |

| Onglet | Contenu |
|---|---|
| Ordonnances (médecin) | ses ordonnances (filtres statut, période, recherche), nouvelle ordonnance, fiche avec actions selon le statut, bandeau des patients sous 80 % d'observance |
| Catalogue | recherche nom / DCI, filtres catégorie et générique, tri par prix, archivage (modification : admin) |
| Assurances / APCI | organismes, plafond, délai de réponse, taux par catégorie ; codes CIM-10 à 100 % |
| Délivrance | scan du QR code ou saisie du numéro, contrôle de la signature, boîtes délivrées ligne par ligne (partielle ou complète), génériques moins chers |
| Aujourd'hui | prises du jour à cocher, navigation par jour, observance 7 jours, stock restant, alerte fin de stock avec bouton Renouveler |
| Ordonnances (patient) | ses ordonnances (sans brouillons), QR code, PDF, simulation du remboursement, création du dossier |
| Remboursements | contrats et plafond consommé, ordonnances à déclarer, dossiers |
| Patients | fiche Ordonnances & Assurance du patient (`OrdonnancesPatientTab`) : traitements, ordonnances, contrats (ajout / résiliation : admin), dossiers |
| Dossiers | tous les dossiers par statut, relances des dossiers sans réponse, réponse CNAM, marquer remboursé |
| Stats | dépenses mensuelles, par patient, CNAM / mutuelle / patient, refus par motif, délai moyen, médicaments coûteux, économie génériques |

Règles : `domain/referentiels_manager.dart` (base) et `domain/regles_referentiels.dart`
(contrôles purs, testés). Un médicament déjà prescrit est archivé au lieu d'être
supprimé ; une assurance ou un code APCI utilisé par un contrat ne se supprime pas.

## Rôle pharmacien

`Role.pharmacien` ajouté dans `models/utilisateur.dart` (fichier commun).
Compte de démo créé par le module : `pharmacien@vitalwatch.tn` / `pharmacien123`.

Droits : `domain/prescriptions_permissions.dart`.

## Données de démo (`data/prescriptions_demo.dart`)

21 médicaments (6 paires princeps / générique), CNAM et Mutuelle VitalSanté avec
leurs taux, 12 codes APCI, contrats des 3 patients de démo et 2 ordonnances :

| Ordonnance | Patient | Médecin | État |
|---|---|---|---|
| ORD-AAAA-0001 | Sarra Trabelsi | Dr Ben Salah (`medecin@vitalwatch.tn`) | délivrée il y a 3 jours, prises en cours (observance < 80 %, Doliprane presque fini) |
| ORD-AAAA-0002 | Youssef Hammami (APCI diabète) | Dr Gharbi (`leila.gharbi@vitalwatch.tn`) | validée aujourd'hui, à délivrer |

Historique créé une seule fois (drapeau `demo_historique`) pour les dossiers et
les statistiques : 5 ordonnances délivrées des 5 derniers mois avec leurs
dossiers (remboursé, refusé « pièce manquante », en cours depuis 40 jours →
relance, partiel).

Prix, taux et plafonds : valeurs d'illustration, modifiables par l'admin.

## Métiers (`domain/`)

| Fichier | Métier |
|---|---|
| `calcul_boites.dart` | boîtes = ⌈dose × prises/jour × durée ÷ unités par boîte⌉ |
| `planning_prises.dart` | une prise par jour et par moment (nuit 3 h, matin 8 h, midi 13 h, après-midi 17 h, soir 20 h, coucher 22 h) |
| `authenticite_ordonnance.dart` | SHA-256 de l'ordonnance, QR `VITALWATCH\|numéro\|hash`, lecture du QR ou du numéro |
| `delivrance_manager.dart` | refuse brouillon, annulée, délivrée, expirée ou signature modifiée ; délivrance partielle ou complète |
| `traitement_manager.dart` | prise oubliée 3 h après l'heure, observance, alerte médecin sous 80 %, stock ≤ 3 jours |
| `calcul_prise_en_charge.dart` | base = min(prix, prix de référence) × boîtes ; CNAM = base × taux (100 % APCI), limitée au plafond ; mutuelle sur le reste |
| `service_cnam_simule.dart` | contrat expiré → refusé ; part > plafond restant → partiel ; sinon accepté (issue forçable pour la démo) |
| `remboursement_manager.dart` | éligibilité, simulateur, dossier brouillon → soumis → en cours → réponse → remboursé, paiement du reste |
| `substitution_generique.dart` | génériques moins chers du catalogue + produits RxNorm de même DCI et dosage |
| `contrat_manager.dart` | numéro d'adhérent 8 chiffres, un seul contrat CNAM actif, APCI seulement avec la CNAM |

## API

| API | Fichier | Usage |
|---|---|---|
| RxNorm (NLM, sans clé) | `data/api/rxnorm_api.dart` | `rxcui.json?name=` puis `related.json?tty=SCD` ; DCI française traduite (`dciAnglais`) |
| Konnect (sandbox) | `data/api/konnect_api.dart` | `POST /payments/init-payment` (montant en millimes) → lien de paiement ; `GET /payments/{ref}` → statut |

Clés Konnect : copier `assets/config/konnect.example.json` en
`assets/config/konnect.json` (ignoré par git) et le remplir, ou
`--dart-define=KONNECT_API_KEY=… --dart-define=KONNECT_WALLET_ID=…`.
Sans clés, le paiement passe en mode démo (référence `DEMO-…`, aucun appel réseau).

## PDF et QR code

`presentation/pdf/ordonnance_pdf.dart` (paquets `pdf`, `printing`) : en-tête
médecin, patient, lignes, QR code. Le pharmacien scanne le QR
(`mobile_scanner`) : numéro inconnu ou hash différent → ordonnance refusée.

## Paquets ajoutés (`pubspec.yaml`, fichier commun)

`pdf`, `printing`, `qr_flutter`, `mobile_scanner`, `url_launcher`.
Caméra iOS : `NSCameraUsageDescription` dans `ios/Runner/Info.plist`.

## Limites connues

- Rappels de prise dans l'application (carte d'accueil, onglet Aujourd'hui) :
  pas encore de notifications système.
- La CNAM n'a pas d'API publique : réponse simulée (`ServiceCnamSimule`).

## Cycle de vie (`domain/ordonnance_manager.dart`)

| Action | Statut de départ | Effet |
|---|---|---|
| Nouvelle ordonnance | — | brouillon daté du jour, valable 90 jours, numéro ORD-AAAA-NNNN |
| Ajouter / modifier une ligne | brouillon | contrôles (dose max, 1 à 6 prises, 1 à 365 jours, DCI en double, APCI), boîtes calculées |
| Valider | brouillon | contrôles bloquants + avertissements (chevauchement, gestion Patients), signature SHA-256, planning des prises, verrouillage |
| Annuler | validée, partiellement délivrée | motif ≥ 10 caractères, reste dans l'historique |
| Corriger | validée, partiellement délivrée | annulation + copie en brouillon (`ordonnance_origine_id`) |
| Renouveler | délivrée, partiellement délivrée, expirée (renouvellements > 0) | copie validée du jour ; le compteur décrémenté passe sur la copie |

## Gestion Patients (Abir)

Ce que le module fournit (`prescriptions_api.dart`, un seul import) :

```dart
import 'package:projet/features/prescriptions/prescriptions_api.dart';

final List<TraitementActif> t = await traitementsActifs(patient.id!); // lecture seule
OrdonnancesPatientTab(patientId: patient.id!); // onglet de la fiche patient
```

Ce que le module attend (`domain/service_patients.dart`) :

| Fonction | Version provisoire actuelle |
|---|---|
| `analyserTraitement(patient, dci, autresDci)` | aucun risque (jamais bloquant) |
| `codesCimChroniques(patient)` | codes APCI des contrats du patient |
| `patientsDuMedecin(medecin)` | patients dont il est le médecin référent |

Pour brancher la vraie version : `ServicePatients.instance = SaVersion();` (une ligne).

## Tests

`flutter test test/features/prescriptions`
