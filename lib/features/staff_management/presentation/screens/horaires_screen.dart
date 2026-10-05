import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/medecin.dart';
import '../../domain/disponibilite.dart';
import '../../domain/staff_manager.dart';
import '../../domain/staff_models.dart';

/// Édition des horaires de consultation hebdomadaires d'un médecin.
/// Renvoie true si les horaires ont été enregistrés.
class HorairesScreen extends StatefulWidget {
  const HorairesScreen({
    super.key,
    required this.medecin,
    required this.creneaux,
  });

  final Medecin medecin;
  final List<Creneau> creneaux;

  @override
  State<HorairesScreen> createState() => _HorairesScreenState();
}

class _HorairesScreenState extends State<HorairesScreen> {
  late List<Creneau> _creneaux = [...widget.creneaux];
  String? _erreur;
  bool _enregistrement = false;

  int get _medecinId => widget.medecin.id ?? 0;

  List<Creneau> _du(int jour) => [
        for (final Creneau c in _creneaux)
          if (c.jour == jour) c,
      ]..sort((a, b) => a.debut.compareTo(b.debut));

  Future<int?> _heure(String aide, int minutes) async {
    final int m = minutes.clamp(0, 23 * 60 + 59);
    final TimeOfDay? t = await showTimePicker(
      context: context,
      helpText: aide,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  /// Demande début puis fin ; null si annulé ou invalide.
  Future<Creneau?> _saisir(int jour, int debutPropose, int finPropose) async {
    final int? debut = await _heure('${Horaire.jours[jour - 1]} — début', debutPropose);
    if (debut == null || !mounted) return null;
    final int? fin = await _heure(
      '${Horaire.jours[jour - 1]} — fin',
      finPropose > debut ? finPropose : debut + 60,
    );
    if (fin == null || !mounted) return null;
    if (fin <= debut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L'heure de fin doit être après l'heure de début")),
      );
      return null;
    }
    return Creneau(medecinId: _medecinId, jour: jour, debut: debut, fin: fin);
  }

  Future<void> _ajouter(int jour) async {
    final List<Creneau> existants = _du(jour);
    final int debut = existants.isEmpty ? 9 * 60 : existants.last.fin + 60;
    final Creneau? c = await _saisir(jour, debut, debut + 4 * 60);
    if (c == null) return;
    setState(() {
      _creneaux = [..._creneaux, c];
      _erreur = null;
    });
  }

  Future<void> _modifier(Creneau ancien) async {
    final Creneau? c = await _saisir(ancien.jour, ancien.debut, ancien.fin);
    if (c == null) return;
    setState(() {
      _creneaux = [
        for (final Creneau x in _creneaux)
          if (identical(x, ancien)) c else x,
      ];
      _erreur = null;
    });
  }

  void _retirer(Creneau c) {
    setState(() {
      _creneaux = [
        for (final Creneau x in _creneaux)
          if (!identical(x, c)) x,
      ];
      _erreur = null;
    });
  }

  void _modele(String choix) {
    setState(() {
      _erreur = null;
      switch (choix) {
        case 'lundi':
          final List<Creneau> lundi = _du(1);
          _creneaux = [
            for (final Creneau c in _creneaux)
              if (c.jour == 1 || c.jour > 5) c,
            for (int j = 2; j <= 5; j++)
              for (final Creneau c in lundi)
                Creneau(medecinId: _medecinId, jour: j, debut: c.debut, fin: c.fin),
          ];
        case 'defaut':
          _creneaux = [
            for (int j = 1; j <= 5; j++)
              Creneau(medecinId: _medecinId, jour: j, debut: 9 * 60, fin: 17 * 60),
          ];
        case 'vider':
          _creneaux = [];
      }
    });
  }

  Future<void> _enregistrer() async {
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      await StaffManager().enregistrerHoraires(_medecinId, _creneaux);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on StaffException catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? erreur = _erreur;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Horaires de consultation'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Modèles',
            onSelected: _modele,
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem<String>(
                value: 'lundi',
                child: Text('Copier le lundi du mardi au vendredi'),
              ),
              PopupMenuItem<String>(
                value: 'defaut',
                child: Text('Lun – ven, 09:00 – 17:00'),
              ),
              PopupMenuItem<String>(
                value: 'vider',
                child: Text('Tout effacer'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            widget.medecin.nomComplet,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${Horaire.heuresParSemaine(_creneaux)} h par semaine · '
            '${Horaire.joursTravailles(_creneaux)} jour(s) travaillé(s)',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (erreur != null) ...[
            ErrorBanner(message: erreur),
            const SizedBox(height: 12),
          ],
          for (int jour = 1; jour <= 7; jour++)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Horaire.jours[jour - 1],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _ajouter(jour),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Créneau'),
                        ),
                      ],
                    ),
                    if (_du(jour).isEmpty)
                      const Text(
                        'Repos',
                        style: TextStyle(color: AppColors.textSecondary),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final Creneau c in _du(jour))
                            InputChip(
                              avatar: const Icon(Icons.schedule_rounded, size: 18),
                              label: Text(c.libelle),
                              onPressed: () => _modifier(c),
                              onDeleted: () => _retirer(c),
                              deleteButtonTooltipMessage: 'Retirer',
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            'Touchez un créneau pour changer les heures.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: PrimaryButton(
            label: 'Enregistrer',
            icon: Icons.check_rounded,
            loading: _enregistrement,
            onPressed: _enregistrer,
          ),
        ),
      ),
    );
  }
}
