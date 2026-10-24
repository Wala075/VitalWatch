import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../models/utilisateur.dart';
import '../../../../home/presentation/widgets/page_title.dart';
import '../demande_urgente_screen.dart';
import '../prise_rdv_screen.dart';
import 'rdv_liste_tab.dart';

/// Espace rendez-vous du PATIENT, affiché dans l'onglet « Planning » de
/// l'accueil (HomeScreen) et réutilisé par AppointmentsScreen.
///
/// Deux gros boutons toujours visibles en haut :
/// - « Prendre RDV » : choix du médecin, du TYPE (présentiel / visio),
///   du jour et de l'horaire ;
/// - « Urgence » (rouge) : consultation urgente non vitale.
class RdvPatientTab extends StatefulWidget {
  const RdvPatientTab({super.key, required this.utilisateur, this.avecTitre = true});

  final Utilisateur utilisateur;

  /// false quand l'écran parent a déjà une AppBar.
  final bool avecTitre;

  @override
  State<RdvPatientTab> createState() => _RdvPatientTabState();
}

class _RdvPatientTabState extends State<RdvPatientTab> {
  final ValueNotifier<int> _rafraichir = ValueNotifier<int>(0);

  @override
  void dispose() {
    _rafraichir.dispose();
    super.dispose();
  }

  Future<void> _prendreRdv() async {
    final bool? cree = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => PriseRdvScreen(utilisateur: widget.utilisateur),
      ),
    );
    if (cree == true) {
      _rafraichir.value++;
    }
  }

  Future<void> _urgence() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => DemandeUrgenteScreen(utilisateur: widget.utilisateur),
      ),
    );
    _rafraichir.value++;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.avecTitre)
            const PageTitle(surtitre: 'Mes', titre: 'Rendez-vous'),
          Padding(
            padding: EdgeInsets.fromLTRB(16, widget.avecTitre ? 0 : 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _GrosBouton(
                    icon: Icons.add_circle_rounded,
                    titre: 'Prendre RDV',
                    sousTitre: 'Présentiel ou visio',
                    couleurs: const [AppColors.primaryDark, AppColors.primary],
                    onTap: _prendreRdv,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GrosBouton(
                    icon: Icons.emergency_rounded,
                    titre: 'Urgence',
                    sousTitre: 'Médecin tout de suite',
                    couleurs: const [Color(0xFFB4232A), AppColors.danger],
                    onTap: _urgence,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RdvListeTab(
              utilisateur: widget.utilisateur,
              rafraichir: _rafraichir,
            ),
          ),
        ],
      ),
    );
  }
}

class _GrosBouton extends StatelessWidget {
  const _GrosBouton({
    required this.icon,
    required this.titre,
    required this.sousTitre,
    required this.couleurs,
    required this.onTap,
  });

  final IconData icon;
  final String titre;
  final String sousTitre;
  final List<Color> couleurs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: couleurs,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        sousTitre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
