# Travailler à plusieurs sur VitalWatch

Dépôt : https://github.com/Wala075/VitalWatch

## Les branches

| Branche | Rôle |
|---|---|
| `main` | Version stable, utilisée pour les démos et la soutenance. On n'y travaille jamais directement. |
| `develop` | Version commune de l'équipe : chaque module y arrive par une Pull Request. |
| `feature/...` | Une branche par module, une seule personne dessus. |

| Module | Dossier | Branche |
|---|---|---|
| 1. Services & Personnel | `lib/features/staff_management` | `feature/gestion-service-personnel` |
| 2. Patients & Suivi vital | `lib/features/patient_monitoring` | `feature/suivi-patients` |
| 3. Ambulances & Interventions | `lib/features/ambulance_dispatch` | `feature/ambulances` |
| 4. Rendez-vous & Téléconsultation | `lib/features/appointments` | `feature/rendez-vous` |
| 5. Ordonnances & Traitements | `lib/features/prescriptions` | `feature/ordonnances` |

## Première fois

```bash
git clone https://github.com/Wala075/VitalWatch.git
cd VitalWatch
git checkout develop
flutter pub get
git checkout -b feature/suivi-patients   # le nom de TA branche
```

Pour l'envoi des mails : copier `assets/config/emailjs.example.json` en
`assets/config/emailjs.json` et y mettre les clés (demandées en privé).
Ce fichier n'est jamais poussé sur GitHub.

## Chaque jour

```bash
# 1. Récupérer le travail des autres
git checkout develop
git pull
git checkout feature/suivi-patients
git merge develop

# 2. Coder, puis enregistrer
git add .
git commit -m "feat(patients): ajout du formulaire de mesure"
git push            # la 1re fois : git push -u origin feature/suivi-patients
```

## Fusionner son travail (Pull Request)

1. Sur GitHub : **Pull requests > New pull request**.
2. `base: develop` ← `compare: feature/ta-branche`.
3. Ajouter un coéquipier en **Reviewer**.
4. Après relecture : **Merge pull request**.
5. Chacun refait ensuite `git pull` sur `develop` puis `git merge develop` dans sa branche.

Avant une démo : Pull Request `develop` → `main`.

## Règles pour ne pas casser l'app

1. Ne jamais pousser directement sur `main` ou `develop`.
2. Travailler uniquement dans le dossier de son module (`lib/features/<module>/`).
3. Fichiers communs (`pubspec.yaml`, `lib/core/`, `lib/models/`, `app_routes.dart`,
   `app_router.dart`, `app_database.dart`) : prévenir le groupe avant de les modifier,
   et faire une petite Pull Request à part.
4. Avant chaque Pull Request : `flutter pub get`, `flutter analyze`, puis lancer l'app.
5. Messages de commit clairs : `feat(module): ...`, `fix(module): ...`.
6. En cas de conflit : Android Studio > **Git > Resolve Conflicts**, garder les deux
   versions si besoin, tester, puis `git commit`.
