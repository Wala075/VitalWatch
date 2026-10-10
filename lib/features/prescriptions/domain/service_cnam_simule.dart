import 'calcul_prise_en_charge.dart';
import 'models/dossier_remboursement.dart';

/// Issue demandée au service simulé : automatique (règles fixes) ou forcée
/// pour la démonstration.
enum IssueCnam {
  automatique('Automatique (règles CNAM)'),
  accepter('Forcer : accepté'),
  partiel('Forcer : partiel'),
  refuser('Forcer : refusé');

  const IssueCnam(this.libelle);

  final String libelle;
}

/// Réponse de la CNAM à un dossier.
class ReponseCnam {
  const ReponseCnam({
    required this.statut,
    required this.partObligatoire,
    required this.resteACharge,
    this.motifRefus,
  });

  final StatutDossier statut;
  final double partObligatoire;
  final double resteACharge;
  final String? motifRefus;
}

/// La CNAM n'a pas d'API publique : le dossier est soumis à ce service
/// simulé (ce n'est pas une API comptée). Règles fixes :
/// contrat expiré → refusé ; part demandée > plafond restant → partiel ;
/// sinon accepté.
class ServiceCnamSimule {
  ServiceCnamSimule._();

  /// Délai de réponse simulé.
  static const Duration delai = Duration(seconds: 2);

  static ReponseCnam repondre({
    required DossierRemboursement dossier,
    required bool contratActif,
    double? plafondRestant,
    IssueCnam issue = IssueCnam.automatique,
    String? motif,
  }) {
    final double part = dossier.partObligatoire;

    ReponseCnam refus(String texte) => ReponseCnam(
          statut: StatutDossier.refuse,
          partObligatoire: 0,
          resteACharge: _reste(dossier, 0),
          motifRefus: texte,
        );

    ReponseCnam partiel(double accorde) {
      final double a = CalculPriseEnCharge.arrondi(accorde < 0 ? 0 : accorde);
      return ReponseCnam(
        statut: StatutDossier.partiel,
        partObligatoire: a,
        resteACharge: _reste(dossier, a),
      );
    }

    final ReponseCnam accepte = ReponseCnam(
      statut: StatutDossier.accepte,
      partObligatoire: part,
      resteACharge: dossier.resteACharge,
    );

    switch (issue) {
      case IssueCnam.accepter:
        return accepte;
      case IssueCnam.partiel:
        return partiel(part / 2);
      case IssueCnam.refuser:
        final String texte = (motif ?? '').trim();
        return refus(texte.isEmpty ? 'Refus simulé (démonstration)' : texte);
      case IssueCnam.automatique:
        if (!contratActif) {
          return refus("Contrat CNAM expiré à la date de l'ordonnance");
        }
        final double? plafond = plafondRestant;
        if (plafond != null && part > plafond + 0.0005) {
          return partiel(plafond);
        }
        return accepte;
    }
  }

  /// Reste à charge quand la CNAM accorde [partAccordee].
  static double _reste(DossierRemboursement d, double partAccordee) {
    return CalculPriseEnCharge.arrondi(d.montantTotal - partAccordee - d.partComplementaire);
  }
}
