import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_dropdown_field.dart';
import '../../../../../core/widgets/confirm_dialog.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../models/medecin.dart';
import '../../../../../models/utilisateur.dart';
import '../../../domain/rdv_manager.dart';
import '../../../domain/rdv_models.dart';
import '../../../domain/rdv_permissions.dart';
import '../../../domain/rdv_regles.dart';
import '../../widgets/rdv_widgets.dart';

/// Gestion des créneaux : le médecin gère les siens, l'admin ceux de tous.
class CreneauxTab extends StatefulWidget {
  const CreneauxTab({super.key, required this.utilisateur});

  final Utilisateur utilisateur;

  @override
  State<CreneauxTab> createState() => _CreneauxTabState();
}

class _CreneauxTabState extends State<CreneauxTab> {
  final RdvManager _manager = RdvManager();

  List<Medecin> _medecins = [];
  int? _medecinId;
  List<Creneau> _creneaux = [];
  bool _chargement = true;

  Utilisateur get _u => widget.utilisateur;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    if (_u.role.gererTousLesCreneaux) {
      final List<Medecin> m = await _manager.medecins();
      if (!mounted) {
        return;
      }
      setState(() {
        _medecins = m;
        _medecinId = m.isEmpty ? null : m.first.id;
      });
    } else {
      _medecinId = _u.refId;
    }
    await _charger();
  }

  Future<void> _charger() async {
    final int? mid = _medecinId;
    final List<Creneau> c = mid == null ? [] : await _manager.creneaux(mid);
    if (!mounted) {
      return;
    }
    setState(() {
      _creneaux = c;
      _chargement = false;
    });
  }

  Future<void> _editer([Creneau? existant]) async {
    final int? mid = _medecinId;
    if (mid == null) {
      return;
    }
    final Creneau? c = await showModalBottomSheet<Creneau>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _CreneauSheet(medecinId: mid, initial: existant),
    );
    if (c == null) {
      return;
    }
    try {
      await _manager.enregistrerCreneau(c, _u);
      if (mounted) {
        afficherInfo(context, 'Créneau enregistré');
      }
    } catch (e) {
      if (mounted) {
        afficherErreur(context, e);
      }
    }
    _charger();
  }

  Future<void> _supprimer(Creneau c) async {
    final bool ok = await showConfirmDialog(
      context,
      titre: 'Supprimer ce créneau ?',
      message: 'Les RDV déjà pris ne sont pas annulés.',
      confirmer: 'Supprimer',
      danger: true,
    );
    if (!ok) {
      return;
    }
    try {
      await _manager.supprimerCreneau(c, _u);
    } catch (e) {
      if (mounted) {
        afficherErreur(context, e);
      }
    }
    _charger();
  }

  String _jourLibelle(Creneau c) {
    final DateTime? d = c.date;
    if (c.recurrent || d == null) {
      return 'Chaque ${RdvFormat.joursLongs[c.jour - 1].toLowerCase()}';
    }
    return 'Le ${RdvFormat.jour(d)} (une fois)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            if (_u.role.gererTousLesCreneaux) ...[
              AppDropdownField<int>(
                label: 'Médecin',
                icon: Icons.medical_services_outlined,
                value: _medecinId,
                items: [
                  for (final Medecin m in _medecins)
                    DropdownMenuItem<int>(value: m.id, child: Text(m.nomComplet)),
                ],
                onChanged: (int? v) {
                  setState(() => _medecinId = v);
                  _charger();
                },
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Plages où les patients peuvent réserver. Chaque plage est découpée '
              'en rendez-vous de la durée indiquée.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: _medecinId == null ? null : () => _editer(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un créneau'),
            ),
            const SizedBox(height: 12),
            if (_chargement)
              const Center(child: CircularProgressIndicator())
            else if (_creneaux.isEmpty)
              const EmptyState(icon: Icons.schedule_rounded, message: 'Aucun créneau défini')
            else
              for (final Creneau c in _creneaux)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      onTap: () => _editer(c),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.mint,
                        child: Icon(
                          c.recurrent ? Icons.repeat_rounded : Icons.event_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        '${RdvFormat.minutes(c.heureDebut)} - ${RdvFormat.minutes(c.heureFin)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('${_jourLibelle(c)} · RDV de ${c.dureeRdv} min'),
                      trailing: IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                        onPressed: () => _supprimer(c),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Formulaire d'un créneau (bottom sheet). Renvoie le créneau saisi.
class _CreneauSheet extends StatefulWidget {
  const _CreneauSheet({required this.medecinId, this.initial});

  final int medecinId;
  final Creneau? initial;

  @override
  State<_CreneauSheet> createState() => _CreneauSheetState();
}

class _CreneauSheetState extends State<_CreneauSheet> {
  late bool _recurrent = widget.initial?.recurrent ?? true;
  late int _jour = widget.initial?.jour ?? 1;
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  late int _debut = widget.initial?.heureDebut ?? 9 * 60;
  late int _fin = widget.initial?.heureFin ?? 12 * 60;
  late int _duree = widget.initial?.dureeRdv ?? 30;
  String? _erreur;

  Future<void> _heure(bool debut) async {
    final int m = debut ? _debut : _fin;
    final TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (t == null) {
      return;
    }
    setState(() {
      if (debut) {
        _debut = t.hour * 60 + t.minute;
      } else {
        _fin = t.hour * 60 + t.minute;
      }
    });
  }

  Future<void> _choisirDate() async {
    final DateTime n = DateTime.now();
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(n) ? n : _date,
      firstDate: DateTime(n.year, n.month, n.day),
      lastDate: DateTime(n.year + 1, n.month, n.day),
    );
    if (d != null) {
      setState(() => _date = d);
    }
  }

  void _valider() {
    final Creneau c = Creneau(
      id: widget.initial?.id,
      medecinId: widget.medecinId,
      jour: _recurrent ? _jour : _date.weekday,
      date: _recurrent ? null : _date,
      heureDebut: _debut,
      heureFin: _fin,
      recurrent: _recurrent,
      dureeRdv: _duree,
    );
    final String? erreur = RdvRegles.validerCreneau(c);
    if (erreur != null) {
      setState(() => _erreur = erreur);
      return;
    }
    Navigator.pop(context, c);
  }

  @override
  Widget build(BuildContext context) {
    final String? erreur = _erreur;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial == null ? 'Nouveau créneau' : 'Modifier le créneau',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _recurrent,
            onChanged: (bool v) => setState(() => _recurrent = v),
            title: const Text('Chaque semaine'),
            subtitle: Text(_recurrent ? 'Créneau récurrent' : 'Une seule date'),
          ),
          if (_recurrent)
            AppDropdownField<int>(
              label: 'Jour',
              icon: Icons.today_rounded,
              value: _jour,
              items: [
                for (int i = 1; i <= 7; i++)
                  DropdownMenuItem<int>(value: i, child: Text(RdvFormat.joursLongs[i - 1])),
              ],
              onChanged: (int? v) => setState(() => _jour = v ?? 1),
            )
          else
            OutlinedButton.icon(
              onPressed: _choisirDate,
              icon: const Icon(Icons.event_rounded),
              label: Text(RdvFormat.jour(_date)),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _heure(true),
                  icon: const Icon(Icons.login_rounded),
                  label: Text('Début ${RdvFormat.minutes(_debut)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _heure(false),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text('Fin ${RdvFormat.minutes(_fin)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppDropdownField<int>(
            label: 'Durée d\'un RDV',
            icon: Icons.timer_outlined,
            value: _duree,
            items: [
              for (final int d in const [15, 20, 30, 45, 60])
                DropdownMenuItem<int>(value: d, child: Text('$d minutes')),
            ],
            onChanged: (int? v) => setState(() => _duree = v ?? 30),
          ),
          if (erreur != null) ...[
            const SizedBox(height: 10),
            Text(erreur, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _valider, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
