import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/api/protection_vocale_service.dart';
import '../../domain/surveillance_cardiaque.dart';

/// « Ça va ? » : 30 s pour annuler, sinon l'ambulance part.
class DialogueAlerteCardiaque extends StatefulWidget {
  const DialogueAlerteCardiaque({super.key, required this.alerte, this.boutons});

  final AlerteCardiaque alerte;

  /// Boutons de la notification (écran verrouillé) : « Annuler » = « Je vais bien ».
  final Stream<String>? boutons;

  @override
  State<DialogueAlerteCardiaque> createState() => _DialogueAlerteCardiaqueState();
}

class _DialogueAlerteCardiaqueState extends State<DialogueAlerteCardiaque> {
  static const int _delai = 30;
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
    final AlerteCardiaque a = widget.alerte;
    return AlertDialog(
      icon: const Icon(Icons.monitor_heart, color: AppColors.danger, size: 44),
      title: Text('${a.mesure.bpm} bpm : rythme ${a.etat.libelle.toLowerCase()}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Est-ce que tout va bien ?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Sans réponse, une ambulance (urgence ${a.gravite.libelle.toLowerCase()}) '
            'sera envoyée dans $_restant s.',
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
          child: const Text('Je vais bien'),
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
