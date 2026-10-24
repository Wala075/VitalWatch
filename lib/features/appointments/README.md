# Module 4 : Rendez-vous & Téléconsultation

Branche : `feature/rendez-vous` · Dossier : `lib/features/appointments`

## Structure

```
appointments/
├── data/                         Accès SQLite
│   ├── rdv_schema.dart           Tables creneaux, rendez_vous, consultations (+ démo)
│   ├── rdv_repository.dart       RDV + jointures + lien avec les alertes du module 2
│   ├── creneau_repository.dart
│   ├── consultation_repository.dart
│   └── personnes_repository.dart Lecture des médecins / patients (module 1)
├── domain/                       Règles métier
│   ├── rdv_models.dart           Creneau, RendezVous, Consultation, stats...
│   ├── rdv_regles.dart           Règles pures (testées) : conflits, file, rappels
│   ├── rdv_permissions.dart      Droits par rôle
│   └── rdv_manager.dart          Point d'entrée unique des écrans
├── services/                     API externes
│   ├── visio_service.dart        Jitsi Meet
│   ├── calendrier_service.dart   Google Calendar
│   ├── resume_ia_service.dart    Gemini (résumé IA)
│   └── compte_rendu_pdf.dart     PDF du compte-rendu
└── presentation/
    ├── screens/                  appointments_screen (onglets par rôle), prise_rdv,
    │                             demande_urgente, rdv_detail, consultation, tabs/
    └── widgets/rdv_widgets.dart  Cartes, badges, rappels
```

Les tables sont créées par le module (`CREATE TABLE IF NOT EXISTS`) :
`app_database.dart` (fichier commun) n'est pas modifié.

## Les 4 utilisateurs

| Rôle | Onglets | Actions |
|---|---|---|
| Patient (`patient@vitalwatch.tn` / `patient123`) | Mes RDV | Prendre RDV, urgence, annuler (≥ 2 h avant), rejoindre la visio, Google Agenda, voir le résumé + PDF |
| Médecin (`medecin@vitalwatch.tn` / `medecin123`) | File du jour · Mes RDV · Créneaux · Stats | Confirmer, démarrer, rédiger la consultation, résumé IA, PDF, absent, gérer ses créneaux |
| Infirmier (`infirmier@vitalwatch.tn` / `infirmier123`) | File du jour · Tous les RDV | RDV / urgence pour un patient, confirmer, absent, annuler |
| Admin (`admin@vitalwatch.tn` / `admin123`) | Tous les RDV · File du jour · Créneaux · Stats | Tout voir, créneaux de tous les médecins, statistiques globales |

## Règles métier

- **Conflits** : pas de RDV hors créneau, ni sur un horaire déjà pris, ni 2 RDV
  en même temps pour un patient. Si conflit : proposition du prochain créneau libre.
- **Urgence non vitale** : sans créneau, médecin du patient sinon le moins
  chargé du service. Visio = maintenant, présentiel = premier horaire libre du jour.
  (Urgence vitale = SOS / ambulance, module 3.)
- **File priorisée** : en cours > urgent > haute (alerte de moins de 48 h dans la
  table `alertes` du module 2) > normale, puis par heure.
- **Rappels** J-1 et H-1 affichés en haut de la liste.
- **Stats** : absentéisme, charge de la semaine, durée réelle moyenne.

## Configuration

- `flutter pub get` (nouvelles dépendances : `url_launcher`, `pdf`, `printing`).
- Résumé IA (optionnel) : copier `assets/config/gemini.example.json` en
  `assets/config/gemini.json` et y mettre une clé de https://aistudio.google.com/apikey.
  Sans clé, un résumé local est utilisé.
- Tests : `flutter test test/features/appointments`.

## Pour le module 2 (Patients)

Pour que les alertes rendent les RDV prioritaires, la table `alertes` doit avoir
au moins les colonnes `patient_id` et `date_heure` (texte ISO 8601).
