import 'package:url_launcher/url_launcher.dart';

import '../domain/rdv_models.dart';

/// Synchronisation avec Google Calendar.
///
/// On utilise le lien « ajouter un événement » de Google Calendar : il ne
/// demande ni clé d'API ni connexion OAuth. L'utilisateur voit l'événement
/// pré-rempli et appuie sur « Enregistrer ».
/// (La vraie API Google Calendar demande un projet Google Cloud + OAuth.)
class CalendrierService {
  CalendrierService._();

  static String _deux(int v) => v.toString().padLeft(2, '0');

  /// Format attendu par Google : 20261007T093000Z (UTC).
  static String formatGoogle(DateTime d) {
    final DateTime u = d.toUtc();
    return '${u.year}${_deux(u.month)}${_deux(u.day)}'
        'T${_deux(u.hour)}${_deux(u.minute)}${_deux(u.second)}Z';
  }

  static Uri lienGoogle(RdvDetail d) {
    final RendezVous r = d.rdv;
    final String? visio = r.lienVisio;
    final StringBuffer details = StringBuffer()
      ..writeln('Motif : ${r.motif}')
      ..writeln('Patient : ${d.patientNom}')
      ..writeln('Médecin : ${d.medecinNom}')
      ..writeln('Type : ${r.type.libelle}');
    if (visio != null) {
      details.writeln('Lien visio : $visio');
    }
    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'RDV VitalWatch - ${d.medecinNom}',
      'dates': '${formatGoogle(r.dateHeure)}/${formatGoogle(r.fin)}',
      'details': details.toString(),
      'location': r.type == TypeRdv.visio
          ? (visio ?? 'Téléconsultation')
          : (d.serviceNom ?? 'VitalWatch'),
    });
  }

  static Future<bool> ajouter(RdvDetail d) {
    return launchUrl(lienGoogle(d), mode: LaunchMode.externalApplication);
  }
}
