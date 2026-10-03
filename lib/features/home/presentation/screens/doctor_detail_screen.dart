import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/demo_data.dart';
import '../../data/demo_store.dart';
import '../widgets/doctor_avatar.dart';
import 'booking_success_screen.dart';

/// Fiche médecin + prise de rendez-vous (jour, créneau, réservation).
class DoctorDetailScreen extends StatefulWidget {
  const DoctorDetailScreen({super.key, required this.medecin});

  final DemoDoctor medecin;

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  static const List<String> _creneaux = [
    '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
    '14:00', '14:30', '15:00', '15:30', '16:00', '16:30',
  ];

  final DemoStore _store = DemoStore.instance;
  late final List<DateTime> _jours;
  int _jour = 0;
  String? _heure;
  bool _reservation = false;

  @override
  void initState() {
    super.initState();
    final DateTime n = DateTime.now();
    _jours = [for (int i = 0; i < 10; i++) DateTime(n.year, n.month, n.day + i)];
  }

  DateTime _dateCreneau(int jour, String heure) {
    final List<String> p = heure.split(':');
    final DateTime j = _jours[jour];
    return DateTime(j.year, j.month, j.day, int.parse(p[0]), int.parse(p[1]));
  }

  /// Créneaux déjà pris (fictifs mais stables) ou déjà passés.
  bool _indisponible(int jour, String heure) {
    if (_dateCreneau(jour, heure).isBefore(DateTime.now())) {
      return true;
    }
    final int code = jour * 31 +
        heure.codeUnitAt(1) * 7 +
        heure.codeUnitAt(3) * 3 +
        widget.medecin.id;
    return code % 5 == 0;
  }

  Future<void> _reserver() async {
    final String? heure = _heure;
    if (heure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez un créneau horaire')),
      );
      return;
    }
    setState(() => _reservation = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final DemoRdv rdv = _store.reserver(widget.medecin, _dateCreneau(_jour, heure));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BookingSuccessScreen(rdv: rdv)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DemoDoctor m = widget.medecin;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _entete(m),
            Transform.translate(
              offset: const Offset(0, -40),
              child: _contenu(m),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _barreReservation(m),
    );
  }

  Widget _entete(DemoDoctor m) {
    return Container(
      height: 330,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.secondary],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  _BoutonRond(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  ListenableBuilder(
                    listenable: _store,
                    builder: (BuildContext context, Widget? child) {
                      final bool favori = _store.estFavori(m);
                      return _BoutonRond(
                        icon: favori ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        couleur: favori ? AppColors.danger : AppColors.textPrimary,
                        onTap: () => _store.basculerFavori(m),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(40),
              ),
              child: DoctorAvatar(medecin: m, taille: 150, rayon: 36),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenu(DemoDoctor m) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.nomComplet,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.specialite,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            m.hopital,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _ChipStatut(enLigne: m.enLigne),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.groups_rounded,
                  couleur: AppColors.primary,
                  valeur: m.patients,
                  libelle: 'Patients',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  icon: Icons.workspace_premium_rounded,
                  couleur: AppColors.purple,
                  valeur: '${m.experience} ans',
                  libelle: 'Expérience',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  icon: Icons.star_rounded,
                  couleur: AppColors.warning,
                  valeur: m.note.toStringAsFixed(1),
                  libelle: 'Note',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _Titre('À propos'),
          const SizedBox(height: 6),
          Text(
            m.apropos,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          const _Titre('Choisir un jour'),
          const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _jours.length,
              separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int i) {
                return _ChipJour(
                  date: _jours[i],
                  aujourdHui: i == 0,
                  actif: i == _jour,
                  onTap: () => setState(() {
                    _jour = i;
                    _heure = null;
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          const _Titre('Choisir une heure'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: [
              for (final String h in _creneaux)
                _ChipHeure(
                  heure: h,
                  actif: h == _heure,
                  indisponible: _indisponible(_jour, h),
                  onTap: () => setState(() => _heure = h),
                ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _barreReservation(DemoDoctor m) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consultation',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  '${m.prix} DT',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PrimaryButton(
                label: 'Prendre rendez-vous',
                icon: Icons.event_available_rounded,
                loading: _reservation,
                onPressed: _reserver,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoutonRond extends StatelessWidget {
  const _BoutonRond({
    required this.icon,
    required this.onTap,
    this.couleur = AppColors.textPrimary,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: couleur),
        ),
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Text(
      texte,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _ChipStatut extends StatelessWidget {
  const _ChipStatut({required this.enLigne});

  final bool enLigne;

  @override
  Widget build(BuildContext context) {
    final Color c = enLigne ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            enLigne ? 'En ligne' : 'Absent',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.couleur,
    required this.valeur,
    required this.libelle,
  });

  final IconData icon;
  final Color couleur;
  final String valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: couleur),
          const SizedBox(height: 6),
          Text(
            valeur,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          Text(
            libelle,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ChipJour extends StatelessWidget {
  const _ChipJour({
    required this.date,
    required this.aujourdHui,
    required this.actif,
    required this.onTap,
  });

  final DateTime date;
  final bool aujourdHui;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 58,
        decoration: BoxDecoration(
          color: actif ? null : AppColors.background,
          gradient: actif
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryDark, AppColors.primary],
                )
              : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              aujourdHui ? 'Auj.' : DateFr.jourCourt(date),
              style: TextStyle(
                fontSize: 12,
                color: actif ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: actif ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipHeure extends StatelessWidget {
  const _ChipHeure({
    required this.heure,
    required this.actif,
    required this.indisponible,
    required this.onTap,
  });

  final String heure;
  final bool actif;
  final bool indisponible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color fond = Colors.white;
    Color texte = AppColors.textPrimary;
    if (indisponible) {
      fond = AppColors.surfaceGrey;
      texte = AppColors.textSecondary.withValues(alpha: 0.6);
    } else if (actif) {
      fond = AppColors.primary;
      texte = Colors.white;
    }

    return GestureDetector(
      onTap: indisponible ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: actif || indisponible ? Colors.transparent : AppColors.divider,
          ),
        ),
        child: Text(
          heure,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: texte,
            decoration: indisponible ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
