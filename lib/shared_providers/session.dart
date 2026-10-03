import '../models/utilisateur.dart';

/// Session utilisateur globale.
/// À migrer vers Provider/Riverpod une fois le state management choisi.
class Session {
  Session._();

  static Utilisateur? utilisateur;

  static bool get estConnecte => utilisateur != null;

  static void fermer() {
    utilisateur = null;
  }
}
