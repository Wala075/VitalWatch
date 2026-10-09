# Module 5 — Ordonnances & Assurance

Branche : `feature/ordonnances` · Responsable : Hamza Mrayhi

Circuit complet d'un médicament prescrit : ordonnance, délivrance, prise du
traitement, remboursement CNAM / mutuelle et paiement du reste à charge.

## Avancement

| Étape | Contenu | État |
|---|---|---|
| 1 | Tables, déclencheurs, modèles, repositories, données de test | fait |
| 2 | Écrans admin : catalogue, assurances, taux, APCI | fait |
| 3 | Ordonnances côté médecin (cycle de vie, boîtes, verrouillage) | à faire |
| 4 | Planning des prises, observance, fin de stock, renouvellement | à faire |
| 5 | Prise en charge, dossiers, service CNAM simulé, plafond | à faire |
| 6 | API RxNorm puis Konnect | à faire |
| 7 | PDF + QR code, statistiques, onglet fiche patient | à faire |

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

| Onglet | Profils | Contenu |
|---|---|---|
| Catalogue | tous (sauf ambulancier) ; modification : admin | recherche nom / DCI, filtres catégorie et générique, tri par prix, archivage |
| Assurances | admin | organismes, plafond, délai de réponse, taux par catégorie (`tous` pour une mutuelle) |
| APCI | admin | codes CIM-10 pris en charge à 100 % |

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
| ORD-AAAA-0001 | Sarra Trabelsi | Dr Ben Salah (`medecin@vitalwatch.tn`) | délivrée il y a 3 jours, prises en cours (observance ≈ 75 %) |
| ORD-AAAA-0002 | Youssef Hammami (APCI diabète) | Dr Gharbi (`leila.gharbi@vitalwatch.tn`) | validée aujourd'hui, à délivrer |

Prix, taux et plafonds : valeurs d'illustration, modifiables par l'admin.

## Métiers déjà codés (`domain/`)

- `calcul_boites.dart` — boîtes = ⌈dose × prises/jour × durée ÷ unités par boîte⌉
- `planning_prises.dart` — une prise par jour et par moment (matin 8 h, midi 13 h, soir 20 h, coucher 22 h)
- `authenticite_ordonnance.dart` — SHA-256 de l'ordonnance, contenu du QR code

## Gestion Patients (Abir)

`analyserTraitement()` et `codesCimChroniques()` n'existent pas encore : une
version provisoire sera branchée à l'étape 3, puis remplacée par son code.

## Tests

`flutter test test/features/prescriptions`
