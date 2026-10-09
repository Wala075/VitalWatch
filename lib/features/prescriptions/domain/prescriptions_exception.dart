/// Règle métier non respectée : le message est affiché tel quel à l'écran.
class PrescriptionsException implements Exception {
  const PrescriptionsException(this.message);

  final String message;

  @override
  String toString() => message;
}
