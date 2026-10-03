class Formatters {
  Formatters._();

  /// 14/05/1990
  static String date(DateTime d) {
    return '${_deux(d.day)}/${_deux(d.month)}/${d.year}';
  }

  /// 1990-05-14 (format stocké en base)
  static String dateIso(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${_deux(d.month)}-${_deux(d.day)}';
  }

  /// +21622123456 -> +216 22 123 456
  static String telephone(String tel) {
    if (tel.startsWith('+216') && tel.length == 12) {
      final String c = tel.substring(4);
      return '+216 ${c.substring(0, 2)} ${c.substring(2, 5)} ${c.substring(5)}';
    }
    return tel;
  }

  static String decimal(double v) => v.toStringAsFixed(1);

  static String pourcentage(double v) => '${(v * 100).round()} %';

  static String _deux(int v) => v.toString().padLeft(2, '0');
}
