import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'app_config.dart';

class AuthService {
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

  // Logout — cancella i token
  void logout() {
    _accessToken = null;
    _refreshToken = null;
    debugPrint('[AUTH] Logout effettuato');
  }
}