import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import '../../data/api/ecoute_vocale_service.dart';
import '../../data/api/protection_vocale_service.dart';
import '../../domain/dispatch_models.dart';
import '../../domain/models/intervention.dart';
import '../../domain/surveillance_cardiaque.dart';
import '../providers/montre_controller.dart';
import '../screens/intervention_detail_screen.dart';
import 'dialogue_alerte_cardiaque.dart';
import 'dispatch_ui.dart';

/// Espace patient : démarre la montre pour toute la session (accueil, SOS,
/// écran montre, écran verrouillé) et affiche ses alertes, où que soit le
/// patient dans l'application : « Ça va ? » 30 s puis ambulance.
/// Placé autour de l'onglet SOS, construit dès l'ouverture de l'accueil.
class HoteMontrePatient extends StatefulWidget {
  const HoteMontrePatient({super.key, required this.child});

  final Widget child;

  @override
  State<HoteMontrePatient> createState() => _HoteMontrePatientState();
}

class _HoteMontrePatientState extends State<HoteMontrePatient> {
  final MontreController _montre = MontreController.instance;
  StreamSubscription<AlerteCardiaque>? _alertes;
  StreamSubscription<String>? _messages;

  @override
  void initState() {
    super.initState();
    _alertes = _montre.alertes.listen(_alerter);
    _messages = _montre.messages.listen((String m) {
      if (mounted) {
        DispatchUi.snack(context, m);
      }
    });
    final Utilisateur? u = Session.utilisateur;
    final int? pid = u != null && u.role == Role.patient ? u.refId : null;
    if (pid != null) {
      // Après la construction de l'écran : demarrer() notifie l'accueil.
      scheduleMicrotask(() => _montre.demarrer(pid));
    }
  }

  @override
  void dispose() {
    _alertes?.cancel();
    _messages?.cancel();
    // Déconnexion : après le démontage de l'arbre (l'accueil écoute aussi).
    scheduleMicrotask(() => _montre.arreter());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _alerter(AlerteCardiaque alerte) async {
    if (_montre.alerteOuverte || !mounted) {
      return;
    }
    _montre.alerteOuverte = true;
    // Écran verrouillé : la notification de la protection vocale affiche
    // l'alerte avec « Annuler » (= « Je vais bien »).
    final bool protection = EcouteVocaleService.instance.permanente;
    final ProtectionVocale notif = ProtectionVocale.instance;
    if (protection) {
      unawaited(notif.afficher(
        '${alerte.mesure.bpm} bpm : rythme ${alerte.etat.libelle.toLowerCase()}',
        'Ça va ? Sans réponse, ambulance dans 30 s',
        annulable: true,
      ));
    }
    final bool? envoyer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogueAlerteCardiaque(
        alerte: alerte,
        boutons: protection ? notif.boutons : null,
      ),
    );
    _montre.alerteOuverte = false;
    _montre.suspendre();
    if (envoyer == true) {
      if (mounted) {
        await envoyerAmbulancePatient(context, alerte.gravite);
      }
      if (protection) {
        unawaited(notif.afficher('Ambulance envoyée', 'Ouvrez VitalWatch pour la suivre'));
      }
    } else {
      if (protection) {
        unawaited(notif.afficherEcoute());
      }
      if (mounted) {
        DispatchUi.snack(context, 'Alerte annulée. Surveillance en pause 15 min.');
      }
    }
  }
}

/// Envoie l'ambulance pour le patient connecté puis ouvre le suivi de
/// l'intervention (alerte cardiaque ou appel vocal).
Future<void> envoyerAmbulancePatient(BuildContext context, Gravite gravite) async {
  try {
    final (ResultatDispatch r, bool demo) =
        await MontreController.instance.envoyerAmbulance(gravite);
    if (!context.mounted) {
      return;
    }
    DispatchUi.snack(
      context,
      '${r.justification ?? 'Alerte transmise'}'
      '${demo ? ' (position de démonstration : Sousse)' : ''}',
    );
    final int? id = r.intervention.id;
    if (id != null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => InterventionDetailScreen(interventionId: id)),
      );
    }
  } on DispatchException catch (e) {
    if (context.mounted) {
      DispatchUi.snack(context, e.message, erreur: true);
    }
  }
}
