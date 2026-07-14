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
  final String workId;
  final String identifier;
  final String title;
  final String author;
  final String date;
  final double? rilevanza;
  final int chunksCount;

  FonteChat({
    required this.workId,
    required this.identifier,
    required this.title,
    required this.author,
    required this.date,
    this.rilevanza,
    required this.chunksCount,
  });

  // Aggiornato per leggere used_books invece di sources 
  factory FonteChat.fromJson(Map<String, dynamic> json) {
    return FonteChat(
      workId: json['work_id']?.toString() ?? '',
      identifier: json['identifier']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      rilevanza: (json['relevance_indicator'] as num?)?.toDouble(),
      chunksCount: (json['chunks_count'] as num?)?.toInt() ?? 0,
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

  // Context session id per modalita' fonti bloccate — null = fonti libere
  String? _contextSessionId;

  String get sessionId => _sessionId;
  String? get contextSessionId => _contextSessionId;

  // Crea una context session vincolata a uno o piu' libri 
  // POST /chat/context-sessions con lista book_ids
  Future<bool> creaContextSession(List<String> bookIds) async {
    try {
      final body = {'book_ids': bookIds};
      debugPrint('[CHAT] POST /chat/context-sessions: $body');

      final response = await _dio.post(
        '${AppConfig.chatBaseUrl}/chat/context-sessions',
        data: body,
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      _contextSessionId = data['context_session_id']?.toString();
      debugPrint('[CHAT] Context session creata: $_contextSessionId');
      return _contextSessionId != null;
    } on DioException catch (e) {
      debugPrint('[CHAT] Errore context session: ${e.message}');
      return false;
    }
  }

  // Resetta la context session — torna a modalita' fonti libere
  void resetContextSession() {
    _contextSessionId = null;
    debugPrint('[CHAT] Context session resettata — modalita\' fonti libere');
  }

  // Invia messaggio al server
  // POST /query con question, session_id, select_code
  // Se _contextSessionId e' impostato → modalita' fonti bloccate su un libro
  Future<MessaggioChat> inviaMessaggio(String domanda) async {
    final body = {
      'question': domanda,
      'session_id': _sessionId,
      'select_code': _selectCode,
      'top_k': 10,
      // Aggiunge context_session_id solo se in modalita' fonti bloccate 
      if (_contextSessionId != null)
        'context_session_id': _contextSessionId,
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

      // Legge used_books invece di sources (campo corretto per POST /query)
      final usedBooksRaw = data['used_books'] as List? ?? [];
      final fonti = usedBooksRaw
          .map((f) => FonteChat.fromJson(f as Map<String, dynamic>))
          .toList();

      debugPrint('[CHAT] Risposta ricevuta: ${testo.substring(0, testo.length.clamp(0, 50))}...');
      debugPrint('[CHAT] Libri usati: ${fonti.map((f) => f.title).join(', ')}');

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