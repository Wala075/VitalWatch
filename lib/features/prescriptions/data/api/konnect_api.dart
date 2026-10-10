import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../domain/prescriptions_exception.dart';

/// Clés Konnect, lues depuis assets/config/konnect.json (fichier ignoré par
/// Git, modèle : konnect.example.json) ou --dart-define.
/// Sans clé, le paiement passe en mode démonstration.
class KonnectConfig {
  KonnectConfig._();

  static const String _fichier = 'assets/config/konnect.json';

  static String apiKey = const String.fromEnvironment('KONNECT_API_KEY');
  static String walletId = const String.fromEnvironment('KONNECT_WALLET_ID');
  static bool sandbox = true;
  static bool _charge = false;

  static bool get estConfigure => apiKey.isNotEmpty && walletId.isNotEmpty;

  static String get urlApi => sandbox
      ? 'https://api.sandbox.konnect.network/api/v2'
      : 'https://api.konnect.network/api/v2';

  static Future<void> charger() async {
    if (_charge) {
      return;
    }
    _charge = true;
    try {
      final Object? json = jsonDecode(await rootBundle.loadString(_fichier));
      if (json is Map<String, dynamic>) {
        final Object? cle = json['KONNECT_API_KEY'];
        final Object? wallet = json['KONNECT_WALLET_ID'];
        final Object? bac = json['KONNECT_SANDBOX'];
        if (cle is String && cle.trim().isNotEmpty) {
          apiKey = cle.trim();
        }
        if (wallet is String && wallet.trim().isNotEmpty) {
          walletId = wallet.trim();
        }
        if (bac is bool) {
          sandbox = bac;
        }
      }
    } catch (_) {
      // Fichier absent : mode démonstration.
    }
  }
}

/// Paiement créé chez Konnect : page à ouvrir et référence à vérifier.
class PaiementInitie {
  const PaiementInitie({required this.payUrl, required this.paymentRef});

  final String payUrl;
  final String paymentRef;
}

/// API Konnect (passerelle de paiement tunisienne) : montant en millimes.
/// init-payment renvoie payUrl et paymentRef ; le statut se vérifie ensuite.
class KonnectApi {
  KonnectApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _delai = Duration(seconds: 20);

  Map<String, String> get _entetes => {
        'x-api-key': KonnectConfig.apiKey,
        'Content-Type': 'application/json',
      };

  Future<PaiementInitie> initier({
    required int montantMillimes,
    required String reference,
    required String description,
    String? prenom,
    String? nom,
    String? email,
    String? telephone,
  }) async {
    await KonnectConfig.charger();
    final Map<String, Object?> corps = {
      'receiverWalletId': KonnectConfig.walletId,
      'token': 'TND',
      'amount': montantMillimes,
      'type': 'immediate',
      'description': description,
      'acceptedPaymentMethods': ['wallet', 'bank_card', 'e-DINAR'],
      'lifespan': 30,
      'checkoutForm': false,
      'addPaymentFeesToAmount': false,
      'firstName': prenom,
      'lastName': nom,
      'phoneNumber': telephone,
      'email': email,
      'orderId': reference,
      'theme': 'light',
    };
    try {
      final http.Response r = await _client
          .post(
            Uri.parse('${KonnectConfig.urlApi}/payments/init-payment'),
            headers: _entetes,
            body: jsonEncode(corps),
          )
          .timeout(_delai);
      if (r.statusCode != 200) {
        throw PrescriptionsException('Konnect a refusé le paiement (code ${r.statusCode})');
      }
      final Object? json = jsonDecode(r.body);
      if (json is! Map<String, dynamic> || json['payUrl'] is! String || json['paymentRef'] is! String) {
        throw const PrescriptionsException('Réponse de Konnect illisible');
      }
      return PaiementInitie(
        payUrl: json['payUrl'] as String,
        paymentRef: json['paymentRef'] as String,
      );
    } on PrescriptionsException {
      rethrow;
    } catch (_) {
      throw const PrescriptionsException('Konnect injoignable : vérifiez la connexion Internet');
    }
  }

  /// true si le paiement est terminé (statut « completed »).
  Future<bool> estPaye(String paymentRef) async {
    await KonnectConfig.charger();
    try {
      final http.Response r = await _client
          .get(Uri.parse('${KonnectConfig.urlApi}/payments/$paymentRef'), headers: _entetes)
          .timeout(_delai);
      if (r.statusCode != 200) {
        return false;
      }
      final Object? json = jsonDecode(r.body);
      if (json is Map<String, dynamic>) {
        final Object? paiement = json['payment'];
        if (paiement is Map<String, dynamic>) {
          return paiement['status'] == 'completed';
        }
      }
      return false;
    } catch (_) {
      throw const PrescriptionsException('Konnect injoignable : vérifiez la connexion Internet');
    }
  }
}
