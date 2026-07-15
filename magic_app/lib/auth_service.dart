import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'app_config.dart';

// NUOVO — extends ChangeNotifier per diventare un ChangeNotifierProvider
// i widget potranno ascoltare isLoggato/accessToken
// e ridisegnarsi automaticamente quando cambiano, senza bisogno di passare
// callback manuali in giro.
class AuthService extends ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  String? _accessToken;
// Token di refresh — da usare in futuro per rinnovare l'access token senza rifare il login
// ignore: unused_field
String? _refreshToken;

  String? get accessToken => _accessToken;
  bool get isLoggato => _accessToken != null;

  // Login con username e password — POST /api/auth/token/
  Future<bool> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '${AppConfig.apiBaseUrl}/api/auth/token/',
        data: {
          'username': username,
          'password': password,
        },
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      _accessToken = data['access'] as String?;
      _refreshToken = data['refresh'] as String?;

      debugPrint('[AUTH] Login riuscito — token ottenuto');
      // NUOVO — avvisa i widget in ascolto (es. badge "loggato" in UI)
      // che lo stato di autenticazione e' cambiato
      notifyListeners();
      return _accessToken != null;
    } on DioException catch (e) {
      debugPrint('[AUTH] Errore login: ${e.message}');
      return false;
    }
  }

  // Scarica il pacchetto ZIP come bytes — POST /api/common/export/package/
  Future<List<int>?> scaricaPacchetto() async {
    if (_accessToken == null) {
      debugPrint('[AUTH] Nessun token — fare login prima');
      return null;
    }

    try {
      final response = await _dio.post(
        '${AppConfig.apiBaseUrl}/api/common/export/package/',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
          },
          // Risposta come bytes binari
          responseType: ResponseType.bytes,
        ),
      );

      debugPrint('[AUTH] Pacchetto scaricato: ${response.data.length} bytes');
      return List<int>.from(response.data as List);
    } on DioException catch (e) {
      debugPrint('[AUTH] Errore download pacchetto: ${e.message}');
      return null;
    }
  }

  // Controlla se il pacchetto sul server e' cambiato rispetto all'ultima
  // versione scaricata — GET /api/common/export/package/check/
  // Risposta attesa dal backend: {"cambiato": true/false}
  // Restituisce:
  //   true  -> il pacchetto e' cambiato, va scaricato
  //   false -> nessun cambiamento, non serve scaricare
  //   null  -> errore di rete/parsing, esito sconosciuto (il chiamante
  //            decide come comportarsi in caso di dubbio)
  Future<bool?> pacchettoCambiato() async {
    if (_accessToken == null) {
      debugPrint('[AUTH] Nessun token — fare login prima di controllare');
      return null;
    }

    try {
      final response = await _dio.get(
        '${AppConfig.apiBaseUrl}/api/common/export/package/check/',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
          },
        ),
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      final cambiato = data['cambiato'] as bool?;
      debugPrint('[AUTH] Check pacchetto — cambiato: $cambiato');
      return cambiato;
    } on DioException catch (e) {
      debugPrint('[AUTH] Errore check pacchetto: ${e.message}');
      return null;
    }
  }

  // Logout — cancella i token
  void logout() {
    _accessToken = null;
    _refreshToken = null;
    debugPrint('[AUTH] Logout effettuato');
    // NUOVO — anche qui lo stato cambia, quindi notifichiamo
    notifyListeners();
  }
}