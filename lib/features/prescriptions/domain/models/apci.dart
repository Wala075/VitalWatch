/// Référentiel APCI : code CIM-10 d'une maladie prise en charge à 100 %
/// (table apci).
class Apci {
  /// Même format que les antécédents de la gestion Patients (ex. E11).
  final String codeCim10;
  final String libelle;

  const Apci({required this.codeCim10, required this.libelle});

  factory Apci.fromMap(Map<String, Object?> map) {
    return Apci(
      codeCim10: map['code_cim10'] as String,
      libelle: map['libelle'] as String,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'code_cim10': codeCim10,
      'libelle': libelle,
    };
  }
}
