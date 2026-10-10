import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/api/ecoute_vocale_service.dart';
import '../../data/api/protection_vocale_service.dart';
import '../../domain/appel_aide.dart';
import 'dispatch_ui.dart';

/// Carte « Alerte vocale » : le téléphone écoute « help », « au secours »,
/// « à l'aide »... ; compte à rebours de 10 s (annulable) puis [onAlerte]
/// envoie l'ambulance.
///
/// [partout] (espace patient) : écoute dans toute l'application, même si
/// l'écran de la carte est caché, + option « même écran verrouillé ».
/// Sinon : seulement quand l'écran de la carte est affiché.
class CarteEcouteVocale extends StatefulWidget {
  const CarteEcouteVocale({
    super.key,
    required this.onAlerte,
    this.peutAlerter,
    this.partout = false,
  });

  final Future<void> Function() onAlerte;

  /// Faux si une autre alerte est déjà affichée : l'appel vocal est ignoré.
  final bool Function()? peutAlerter;

  final bool partout;

  @override
  State<CarteEcouteVocale> createState() => _CarteEcouteVocaleState();
}

class _CarteEcouteVocaleState extends State<CarteEcouteVocale> {
  final EcouteVocaleService _ecoute = EcouteVocaleService.instance;
  final ProtectionVocale _protection = ProtectionVocale.instance;
  bool _abonne = false;
  bool _changement = false;

  @override
  void initState() {
    super.initState();
    if (widget.partout) {
      unawaited(_ecoute.restaurerPermanente());
    }
  }

  /// [partout] : toujours abonné. Sinon micro actif seulement si l'écran est
  /// visible (onglet caché de l'accueil ou écran recouvert → TickerMode off).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool doit = widget.partout || TickerMode.valuesOf(context).enabled;
    if (doit && !_abonne) {
      _ecoute.abonner(_surAppel);
      _abonne = true;
    } else if (!doit && _abonne) {
      _ecoute.desabonner(_surAppel);
      _abonne = false;
    }
  }

  @override
  void dispose() {
    if (_abonne) {
      _ecoute.desabonner(_surAppel);
    }
    super.dispose();
  }

  Future<void> _surAppel(AppelAide appel) async {
    final bool Function()? peut = widget.peutAlerter;
    if (!mounted || (peut != null && !peut())) {
      _ecoute.reprendre();
      return;
    }
    // Écran verrouillé / app en arrière-plan : la notification montre le
    // compte à rebours avec un bouton « Annuler ».
    final bool protection = _ecoute.permanente;
    if (protection) {
      unawaited(_protection.afficher(
        "Appel à l'aide détecté",
        '« ${appel.texte} » · ambulance dans 10 s',
        annulable: true,
      ));
    }
    final bool? envoyer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogueAppelVocal(
        appel: appel,
        boutons: protection ? _protection.boutons : null,
      ),
    );
    if (envoyer == true) {
      await widget.onAlerte();
      if (protection) {
        unawaited(_protection.afficher(
          'Ambulance envoyée',
          'Ouvrez VitalWatch pour la suivre · protection vocale toujours active',
        ));
      }
    } else {
      if (protection) {
        unawaited(_protection.afficherEcoute());
      }
      if (mounted) {
        DispatchUi.snack(context, 'Alerte vocale annulée');
      }
    }
    _ecoute.reprendre();
  }

  Future<void> _basculerPermanente(bool oui) async {
    setState(() => _changement = true);
    final String? erreur = await _ecoute.activerPermanente(oui);
    if (!mounted) {
      return;
    }
    setState(() => _changement = false);
    DispatchUi.snack(
      context,
      erreur ??
          (oui
              ? 'Protection active : « help » est entendu même écran verrouillé'
              : 'Protection permanente coupée'),
      erreur: erreur != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ecoute,
      builder: (BuildContext context, Widget? _) {
        final EtatEcoute etat = _ecoute.etat;
        final bool ecoute = etat == EtatEcoute.ecoute;
        final bool probleme = etat == EtatEcoute.indisponible || etat == EtatEcoute.refusee;
        final String entendu = _ecoute.entendu;
        return Section(
          titre: 'Alerte vocale',
          icone: Icons.record_voice_over_outlined,
          action: Switch(
            value: _ecoute.activee,
            onChanged: _ecoute.activer,
          ),
          children: [
            Row(
              children: [
                Icon(
                  ecoute ? Icons.mic : Icons.mic_off_outlined,
                  size: 20,
                  color: ecoute
                      ? AppColors.danger
                      : (probleme ? AppColors.warning : AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    etat.libelle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: ecoute ? FontWeight.w700 : FontWeight.w500,
                      color: probleme ? AppColors.danger : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (probleme)
                  TextButton(
                    onPressed: _ecoute.reessayer,
                    child: const Text('Réessayer'),
                  ),
              ],
            ),
            if (ecoute && entendu.isNotEmpty)
              Text(
                'Entendu : « $entendu »',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            // Service de premier plan : Android uniquement.
            if (widget.partout && Theme.of(context).platform == TargetPlatform.android)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  _ecoute.permanente ? Icons.lock_clock : Icons.lock_open_outlined,
                  color: _ecoute.permanente ? AppColors.danger : AppColors.textSecondary,
                ),
                title: const Text('Même écran verrouillé'),
                subtitle: const Text('Notification fixe · micro et GPS actifs en arrière-plan'),
                value: _ecoute.permanente,
                onChanged: _changement || !_ecoute.activee ? null : _basculerPermanente,
              ),
            Info(
              icone: Icons.info_outline,
              texte: !widget.partout
                  ? 'Écran ouvert uniquement · 10 s pour annuler'
                  : (_ecoute.permanente
                      ? 'Partout, même écran verrouillé · 10 s pour annuler'
                      : 'Dans toute l\'application · 10 s pour annuler'),
            ),
          ],
        );
      },
    );
  }
}

/// « Appel à l'aide détecté » : 10 s pour annuler, sinon l'ambulance part.
class DialogueAppelVocal extends StatefulWidget {
  const DialogueAppelVocal({super.key, required this.appel, this.boutons});

  final AppelAide appel;

  /// Boutons de la notification (écran verrouillé) : « Annuler » ferme aussi
  /// ce dialogue.
  final Stream<String>? boutons;

  @override
  State<DialogueAppelVocal> createState() => _DialogueAppelVocalState();
}

class _DialogueAppelVocalState extends State<DialogueAppelVocal> {
  static const int _delai = 10;
  int _restant = _delai;
  Timer? _minuterie;
  StreamSubscription<String>? _notification;

  @override
  void initState() {
    super.initState();
    _notification = widget.boutons?.listen((String id) {
      if (mounted && id == ProtectionVocale.boutonAnnuler) {
        _minuterie?.cancel();
        Navigator.pop(context, false);
      }
    });
    _minuterie = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        return;
      }
      if (_restant <= 1) {
        t.cancel();
        Navigator.pop(context, true);
        return;
      }
      setState(() => _restant--);
    });
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    _notification?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.record_voice_over, color: AppColors.danger, size: 44),
      title: const Text("Appel à l'aide détecté"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '« ${widget.appel.texte} »',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Une ambulance sera envoyée dans $_restant s.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _restant / _delai,
            minHeight: 6,
            color: AppColors.danger,
            backgroundColor: AppColors.surfaceGrey,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Envoyer maintenant'),
        ),
      ],
    );
  }
}
