import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'app_config.dart';

class MessaggioChat {
  final String testo;
  final bool isUtente;
  final DateTime timestamp;
  final List<FonteChat> fonti;

  MessaggioChat({
    required this.testo,
    required this.isUtente,
    required this.timestamp,
    this.fonti = const [],
  });
}

class FonteChat {
  final String identifier;
  final String title;
  final double? rilevanza;

  FonteChat({
    required this.identifier,
    required this.title,
    this.rilevanza,
  });

  factory FonteChat.fromJson(Map<String, dynamic> json) {
    return FonteChat(
      identifier: json['identifier'] as String? ?? '',
      title: json['title'] as String? ?? json['identifier'] as String? ?? '',
      rilevanza: (json['relevance_indicator'] as num?)?.toDouble(),
    );
  }
}

class ChatService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  // Genera UUID per la sessione 
  final String _sessionId = const Uuid().v4();

  // Codice collezione da AppConfig — aggiornare quando disponibile dataset Girolamini
  final String _selectCode = AppConfig.chatSelectCode;

  String get sessionId => _sessionId;

  // Invia messaggio al server 
  // POST /query con question, session_id, select_code
  Future<MessaggioChat> inviaMessaggio(String domanda) async {
    final body = {
      'question': domanda,
      'session_id': _sessionId,
      'select_code': _selectCode,
    };

    debugPrint('[CHAT] POST /query: $body');

    try {
      final response = await _dio.post(
        '${AppConfig.chatBaseUrl}/query',
        data: body,
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      // Estrae testo risposta
      final testo = data['answer'] as String? ??
          data['text'] as String? ??
          data['response'] as String? ??
          'Nessuna risposta ricevuta';

      // Estrae fonti/libri consultati
      final fontiRaw = data['sources'] as List? ?? [];
      final fonti = fontiRaw
          .map((f) => FonteChat.fromJson(f as Map<String, dynamic>))
          .toList();

      debugPrint('[CHAT] Risposta ricevuta: ${testo.substring(0, testo.length.clamp(0, 50))}...');

      return MessaggioChat(
        testo: testo,
        isUtente: false,
        timestamp: DateTime.now(),
        fonti: fonti,
      );
    } on DioException catch (e) {
      debugPrint('[CHAT] Errore: ${e.message}');
      throw Exception('Errore comunicazione chat: ${e.message}');
    }
  }

  // Recupera dettagli libro tramite identifier 
  // GET /book/{identifier}
  Future<Map<String, dynamic>?> dettagliLibro(String identifier) async {
    try {
      final response = await _dio.get(
        '${AppConfig.chatBaseUrl}/book/$identifier',
      );
      return response.data is String
          ? jsonDecode(response.data)
          : response.data;
    } on DioException catch (e) {
      debugPrint('[CHAT] Errore dettagli libro: ${e.message}');
      return null;
    }
  }
}