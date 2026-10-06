import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/utilisateur.dart';
import '../../../../shared_providers/session.dart';
import '../../data/api/montre_ble_service.dart';
import '../../domain/surveillance_cardiaque.dart';
import '../providers/dispatch_controller.dart';
import '../providers/montre_controller.dart';
import '../widgets/carte_rythme.dart';
import '../widgets/dispatch_ui.dart';
import '../widgets/ecoute_vocale.dart';
import '../widgets/hote_montre_patient.dart';
import '../widgets/tableau_montre.dart';

/// Espace patient (celui qui porte la montre) : détail de la montre Mibro C2.
/// La connexion, la synchro toutes les 30 s, l'enregistrement des mesures et
/// les alertes tournent pour toute la session ([MontreController]) : cet
/// écran les affiche (courbe 3 h, batterie, pas, seuils du médecin, démo).
class SurveillanceCardiaqueScreen extends StatefulWidget {
  const SurveillanceCardiaqueScreen({super.key});

  @override
  State<SurveillanceCardiaqueScreen> createState() => _SurveillanceCardiaqueScreenState();
}

class _SurveillanceCardiaqueScreenState extends State<SurveillanceCardiaqueScreen> {
  final MontreController _ctrl = MontreController.instance;
  double _bpmSimule = 155;

  @override
  void initState() {
    super.initState();
    DispatchController.instance.demarrer();
    // Normalement déjà démarrée par l'espace patient.
    final Utilisateur? u = Session.utilisateur;
    final int? pid = u != null && u.role == Role.patient ? u.refId : null;
    if (pid != null && !_ctrl.demarre) {
      scheduleMicrotask(() => _ctrl.demarrer(pid));
    }
  }

  Future<void> _simuler() async {
    final String? message = await _ctrl.simuler(_bpmSimule.round());
    if (message != null && mounted) {
      DispatchUi.snack(context, message);
    }
  }

  /// « help » / « au secours » entendu et non annulé.
  Future<void> _alerteVocale() => envoyerAmbulancePatient(context, _ctrl.graviteVocale());

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (BuildContext context, Widget? _) {
        final MesureCardiaque? derniere = _ctrl.derniere;
        final SeuilsCardiaques seuils = _ctrl.seuils;
        final AnalyseurCardiaque analyseur = _ctrl.analyseur;
        final DateTime? finPause = analyseur.finPause;
        final String? erreur = _ctrl.erreur;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Ma montre'),
            actions: [
              IconButton(
                tooltip: 'Lire maintenant',
                icon: _ctrl.lecture
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: _ctrl.lecture ? null : () => _ctrl.lire(),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              _connexion(),
              const SizedBox(height: 14),
              CarteRythme(
                derniere: derniere,
                etat: derniere == null ? null : seuils.evaluer(derniere.bpm),
                mesures: _ctrl.mesures,
                seuils: seuils,
                anomalies: analyseur.anomaliesEnCours,
              ),
              if (erreur != null) ...[
                const SizedBox(height: 8),
                Info(icone: Icons.error_outline, texte: erreur, couleur: AppColors.danger),
              ],
              const SizedBox(height: 14),
              CarteEcouteVocale(
                onAlerte: _alerteVocale,
                peutAlerter: () => !_ctrl.alerteOuverte,
              ),
              const SizedBox(height: 14),
              Section(
                titre: "Seuils d'alerte",
                icone: Icons.tune,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${seuils.min} – ${seuils.max} bpm',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const Pastille(
                        libelle: 'Fixés par le médecin',
                        couleur: AppColors.primary,
                        icone: Icons.lock_outline,
                      ),
                    ],
                  ),
                  Info(
                    icone: Icons.info_outline,
                    texte: 'Alerte si < ${seuils.min} ou > ${seuils.max} bpm sur '
                        '${analyseur.mesuresConsecutives} mesures de suite, '
                        'puis 30 s pour répondre « Je vais bien »',
                  ),
                  if (finPause != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Info(
                            icone: Icons.pause_circle_outline,
                            texte: 'Alertes en pause jusqu\'à ${DispatchUi.heure(finPause)}',
                            couleur: AppColors.warning,
                          ),
                        ),
                        TextButton(onPressed: _ctrl.reprendre, child: const Text('Reprendre')),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Section(
                titre: 'Partage avec le médecin',
                icone: Icons.sync,
                children: [
                  if (_ctrl.patientId != null) ...[
                    Info(
                      icone: Icons.verified_user_outlined,
                      texte: Session.utilisateur?.nomComplet ?? 'Patient connecté',
                      couleur: AppColors.textPrimary,
                    ),
                    const Info(
                      icone: Icons.cloud_done_outlined,
                      texte: 'Chaque mesure va dans votre dossier : médecin et régulation la voient',
                    ),
                  ] else
                    const Info(
                      icone: Icons.warning_amber_rounded,
                      texte: 'Compte patient requis pour enregistrer les mesures',
                      couleur: AppColors.danger,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Section(
                titre: 'Mode démo',
                icone: Icons.science_outlined,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: AppColors.danger, size: 18),
                      Expanded(
                        child: Slider(
                          value: _bpmSimule,
                          min: 30,
                          max: 200,
                          divisions: 170,
                          label: '${_bpmSimule.round()} bpm',
                          onChanged: (double v) => setState(() => _bpmSimule = v),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text(
                          '${_bpmSimule.round()} bpm',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: _simuler,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Simuler 2 mesures'),
                  ),
                  const Info(
                    icone: Icons.info_outline,
                    texte: 'Pour la soutenance : déclenche la même chaîne qu\'une vraie '
                        'mesure (alerte → « Ça va ? » → ambulance)',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _connexion() {
    final MontreBleService montre = _ctrl.montre;
    final EtatMontre? etat = _ctrl.etat;
    final bool ok = etat == EtatMontre.connectee;
    final DateTime? lu = _ctrl.derniereLecture;
    final int? batterie = montre.batterie;
    final bool batterieFaible = batterie != null && batterie <= 15 && !montre.enCharge;

    return Section(
      titre: 'Montre Mibro C2 (Bluetooth)',
      icone: Icons.watch_outlined,
      action: etat == null
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Pastille(
              libelle: ok ? 'Connectée' : 'Non connectée',
              couleur: ok ? AppColors.success : AppColors.danger,
              icone: ok ? Icons.check_circle_outline : Icons.link_off,
            ),
      children: [
        Info(
          icone: Icons.info_outline,
          texte: etat == null
              ? 'Recherche de la montre...'
              : (ok ? '${etat.libelle} (${montre.nomMontre})' : etat.libelle),
        ),
        if (ok && lu != null)
          Info(
            icone: Icons.schedule,
            texte: 'Dernière lecture ${DispatchUi.heure(lu)} · toutes les 30 s',
          ),
        if (batterieFaible)
          Info(
            icone: Icons.battery_alert,
            texte: 'Batterie faible ($batterie %) : recharge la montre, '
                'sinon la surveillance s\'arrête',
            couleur: AppColors.danger,
          ),
        if (ok) TableauMontre(montre: montre),
        if (ok)
          const Info(
            icone: Icons.timer_outlined,
            texte: 'Mesure automatique : à activer dans Mibro Fit '
                '(surveillance continue du rythme cardiaque)',
          ),
        if (etat != null && !ok && etat != EtatMontre.indisponible)
          FilledButton.icon(
            onPressed: _ctrl.connecter,
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('Connecter la montre'),
          ),
        if (etat == EtatMontre.indisponible)
          const Info(
            icone: Icons.phone_android,
            texte: 'Lancez l\'app sur un vrai téléphone Android avec Bluetooth. '
                'Le mode démo reste utilisable.',
          ),
      ],
    );
  }
}
