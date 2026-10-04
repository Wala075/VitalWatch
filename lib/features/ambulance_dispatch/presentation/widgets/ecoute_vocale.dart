import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/api/ecoute_vocale_service.dart';
import '../../domain/appel_aide.dart';
import 'dispatch_ui.dart';

/// Carte « Alerte vocale » : tant que l'écran est ouvert, le téléphone écoute
/// « help », « au secours », « à l'aide »... ; compte à rebours de 10 s
/// (annulable) puis [onAlerte] envoie l'ambulance.
class CarteEcouteVocale extends StatefulWidget {
  const CarteEcouteVocale({super.key, required this.onAlerte, this.peutAlerter});

  final Future<void> Function() onAlerte;

  /// Faux si une autre alerte est déjà affichée : l'appel vocal est ignoré.
  final bool Function()? peutAlerter;

  @override
  State<CarteEcouteVocale> createState() => _CarteEcouteVocaleState();
}

class _CarteEcouteVocaleState extends State<CarteEcouteVocale> {
  final EcouteVocaleService _ecoute = EcouteVocaleService.instance;

  @override
  void initState() {
    super.initState();
    _ecoute.abonner(_surAppel);
  }

  @override
  void dispose() {
    _ecoute.desabonner(_surAppel);
    super.dispose();
  }

  Future<void> _surAppel(AppelAide appel) async {
    final bool Function()? peut = widget.peutAlerter;
    if (!mounted || (peut != null && !peut())) {
      _ecoute.reprendre();
      return;
    }
    final bool? envoyer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogueAppelVocal(appel: appel),
    );
    if (!mounted) {
      _ecoute.reprendre();
      return;
    }
    if (envoyer == true) {
      await widget.onAlerte();
    } else {
      DispatchUi.snack(context, 'Alerte vocale annulée');
    }
    _ecoute.reprendre();
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
            const Info(
              icone: Icons.info_outline,
              texte: 'Écran ouvert uniquement · 10 s pour annuler',
            ),
          ],
        );
      },
    );
  }
}

/// « Appel à l'aide détecté » : 10 s pour annuler, sinon l'ambulance part.
class DialogueAppelVocal extends StatefulWidget {
  const DialogueAppelVocal({super.key, required this.appel});

  final AppelAide appel;

  @override
  State<DialogueAppelVocal> createState() => _DialogueAppelVocalState();
}

class _DialogueAppelVocalState extends State<DialogueAppelVocal> {
  static const int _delai = 10;
  int _restant = _delai;
  Timer? _minuterie;

  @override
  void initState() {
    super.initState();
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
