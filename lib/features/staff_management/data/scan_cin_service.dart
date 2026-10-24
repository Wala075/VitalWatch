import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/gemini_config.dart';
import '../domain/lecture_cin.dart';
import 'lecture_cin_gemini.dart';

enum SourcePhoto { camera, galerie }

/// Scan d'une pièce d'identité.
/// 1. API Google Gemini (si la clé est configurée) : lit tout le texte arabe
///    de la CIN et le renvoie translittéré en français.
/// 2. Sinon, ou si Gemini échoue : API Google ML Kit sur le téléphone
///    (pas d'envoi de la photo) : numéro de CIN seulement, ou MRZ du passeport.
class ScanCinService {
  /// ML Kit n'existe que sur Android et iOS.
  static bool get _mlKit =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get disponible => GeminiConfig.estConfigure || _mlKit;

  /// Lecture complète (arabe → français) possible.
  static bool get lectureComplete => GeminiConfig.estConfigure;

  /// Photo de la pièce d'identité → champs reconnus.
  /// null si l'utilisateur annule.
  Future<ResultatScan?> scanner(SourcePhoto source) async {
    final XFile? photo = await ImagePicker().pickImage(
      source: source == SourcePhoto.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (photo == null) return null;

    String? echecGemini;
    if (GeminiConfig.estConfigure) {
      try {
        final Uint8List octets = await photo.readAsBytes();
        final Map<String, dynamic> champs =
            await LectureCinGemini().lire(octets, _typeMime(photo));
        return LectureCin.depuisGemini(champs);
      } on LectureCinException catch (e) {
        echecGemini = e.message;
      }
    }

    if (!_mlKit) {
      return ResultatScan(
        avertissement: echecGemini ?? 'Lecture impossible sur cet appareil',
      );
    }
    final TextRecognizer lecteur =
        TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText texte =
          await lecteur.processImage(InputImage.fromFilePath(photo.path));
      final ResultatScan r = LectureCin.analyser(texte.text);
      return echecGemini == null
          ? r
          : r.avecAvertissement('$echecGemini (numéro seulement)');
    } finally {
      await lecteur.close();
    }
  }

  static String _typeMime(XFile f) {
    final String? m = f.mimeType;
    if (m != null && m.startsWith('image/')) return m;
    final String p = f.path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
