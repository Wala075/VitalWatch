import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/routing/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../models/utilisateur.dart';
import '../../../../../shared_providers/session.dart';
import '../../../data/demo_data.dart';
import '../../../data/demo_store.dart';
import '../../widgets/countdown_chip.dart';
import '../../widgets/doctor_avatar.dart';
import '../../widgets/ecg_painter.dart';
import '../../widgets/page_title.dart';
import '../doctor_detail_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final DemoStore _store = DemoStore.instance;
  Timer? _timer;
  int _astuce = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() => _astuce = (_astuce + 1) % DemoData.astuces.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _salutation {
    final int h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  void _ouvrirMedecin(DemoDoctor m) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DoctorDetailScreen(medecin: m)),
    );
  }

  void _ouvrirProfil() {
    final Utilisateur? u = Session.utilisateur;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  u?.nomComplet ?? 'Invité',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  u == null ? '' : '${u.role.libelle} · ${u.email}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                  title: const Text(
                    'Déconnexion',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Session.fermer();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (BuildContext context, Widget? child) {
        final Utilisateur? u = Session.utilisateur;
        final String prenom =
            u == null || u.prenom.isEmpty ? 'Bienvenue' : u.prenom;

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              _entete(prenom),
              const SizedBox(height: 18),
              _recherche(),
              const SizedBox(height: 18),
              _prochainRdv(),
              const SizedBox(height: 24),
              SectionHeader(
                titre: 'Spécialités',
                action: 'Voir tout',
                onAction: () => _store.allerA(1),
              ),
              const SizedBox(height: 12),
              _specialites(),
              const SizedBox(height: 24),
              const SectionHeader(titre: "Votre santé aujourd'hui"),
              const SizedBox(height: 12),
              _santeDuJour(),
              const SizedBox(height: 24),
              SectionHeader(
                titre: 'Meilleurs médecins',
                action: 'Voir tout',
                onAction: () => _store.allerA(1),
              ),
              const SizedBox(height: 12),
              _meilleursMedecins(),
              const SizedBox(height: 18),
              _carteAstuce(),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- en-tête
  Widget _entete(String prenom) {
    return Row(
      children: [
        GestureDetector(
          onTap: _ouvrirProfil,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
            ),
            child: Text(
              prenom.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _salutation,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                prenom,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        _BoutonRond(
          icon: Icons.notifications_none_rounded,
          pastille: true,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune nouvelle notification')),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- recherche
  Widget _recherche() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _store.allerA(1),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  SizedBox(width: 10),
                  Text(
                    'Rechercher un médecin',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _store.allerA(1),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------ prochain rendez-vous
  Widget _prochainRdv() {
    final DemoRdv? rdv = _store.prochain;
    final BoxDecoration deco = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primaryDark, AppColors.primary],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );

    if (rdv == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: deco,
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Aucun rendez-vous prévu.\nTrouvez un médecin en quelques secondes.',
                style: TextStyle(color: Colors.white, height: 1.4),
              ),
            ),
            _FlecheBlanche(onTap: () => _store.allerA(1)),
          ],
        ),
      );
    }

    final DemoDoctor m = rdv.medecin;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: deco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Prochain rendez-vous',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              CountdownChip(date: rdv.date, surFondSombre: true),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              DoctorAvatar(medecin: m, taille: 54, rayon: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.nomComplet,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.specialite,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Pastille(
                icon: Icons.calendar_today_rounded,
                texte: DateFr.jourLong(rdv.date),
              ),
              const SizedBox(width: 8),
              _Pastille(
                icon: Icons.access_time_rounded,
                texte: DateFr.heure(rdv.date),
              ),
              const Spacer(),
              _FlecheBlanche(onTap: () => _ouvrirMedecin(m)),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ spécialités
  Widget _specialites() {
    final List<Specialite> liste = DemoData.specialites.take(5).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final Specialite s in liste)
          GestureDetector(
            onTap: () => _store.allerA(1, categorie: s.nom),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: s.couleur.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(s.icon, color: s.couleur, size: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  s.nom,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --------------------------------------------------------- santé du jour
  Widget _santeDuJour() {
    return SizedBox(
      height: 150,
      child: Row(
        children: [
          Expanded(
            child: _CarteMesure(
              icon: Icons.favorite_rounded,
              couleur: AppColors.danger,
              titre: 'Cœur',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '72',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(width: 4),
                      Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'bpm',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 30,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: EcgPainter(couleur: AppColors.danger, epaisseur: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: _CarteMesure(
              icon: Icons.directions_walk_rounded,
              couleur: AppColors.primary,
              titre: 'Pas',
              child: Center(
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: 0.72,
                          strokeWidth: 7,
                          strokeCap: StrokeCap.round,
                          backgroundColor: AppColors.surfaceGrey,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '7.2k',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CarteMesure(
              icon: Icons.bedtime_rounded,
              couleur: AppColors.indigo,
              titre: 'Sommeil',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '7.3h',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    'Bon',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      value: 0.85,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceGrey,
                      color: AppColors.indigo,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------ meilleurs médecins
  Widget _meilleursMedecins() {
    final List<DemoDoctor> top = List<DemoDoctor>.of(DemoData.medecins)
      ..sort((a, b) => b.note.compareTo(a.note));

    return SizedBox(
      height: 222,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: top.length < 5 ? top.length : 5,
        separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int i) {
          final DemoDoctor m = top[i];
          return _CarteMedecin(
            medecin: m,
            favori: _store.estFavori(m),
            onFavori: () => _store.basculerFavori(m),
            onTap: () => _ouvrirMedecin(m),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------- astuce
  Widget _carteAstuce() {
    final Astuce a = DemoData.astuces[_astuce];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      transitionBuilder: (Widget child, Animation<double> anim) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<int>(_astuce),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(a.icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.titre,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.texte,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================== widgets

class _BoutonRond extends StatelessWidget {
  const _BoutonRond({required this.icon, required this.onTap, this.pastille = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool pastille;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: AppColors.textPrimary),
              if (pastille)
                Positioned(
                  top: 12,
                  right: 13,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlecheBlanche extends StatelessWidget {
  const _FlecheBlanche({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.icon, required this.texte});

  final IconData icon;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            texte,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteMesure extends StatelessWidget {
  const _CarteMesure({
    required this.icon,
    required this.couleur,
    required this.titre,
    required this.child,
  });

  final IconData icon;
  final Color couleur;
  final String titre;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: couleur),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  titre,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _CarteMedecin extends StatelessWidget {
  const _CarteMedecin({
    required this.medecin,
    required this.favori,
    required this.onFavori,
    required this.onTap,
  });

  final DemoDoctor medecin;
  final bool favori;
  final VoidCallback onFavori;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          width: 150,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    DoctorAvatar(medecin: medecin, taille: 130, rayon: 16),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: onFavori,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            favori ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 16,
                            color: favori ? AppColors.danger : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  medecin.nomComplet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                Text(
                  medecin.specialite,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 15, color: AppColors.warning),
                    const SizedBox(width: 2),
                    Text(
                      medecin.note.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${medecin.prix} DT',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
