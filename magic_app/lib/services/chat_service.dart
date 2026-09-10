import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../core/app_config.dart';

class MessaggioChat {
  final String testo;
  final bool isUtente;
  final DateTime timestamp;
  final List<FonteChat> fonti;
  final bool isSystem;

  MessaggioChat({
    required this.testo,
    required this.isUtente,
    required this.timestamp,
    this.fonti = const [],
    this.isSystem = false,
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

class ChatService extends ChangeNotifier {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  final String _selectCode = AppConfig.chatSelectCode;
  String _sessionId = const Uuid().v4();
  String? _contextSessionId;
  String? _activeRoomCode;
  int? _lastRevision;
  String? _lastUpdatedAt;
  List<MessaggioChat> messaggi = [];
  List<FonteChat> fontiTotali = [];

  String get sessionId => _sessionId;
  String? get contextSessionId => _contextSessionId;

  // ==========================================
  // GESTIONE CONTESTO E DOMANDE
  // ==========================================

  void aggiornaFonti(List<FonteChat> nuoveFonti) {
    for (final fonte in nuoveFonti) {
      if (!fontiTotali.any(
        (f) => f.workId == fonte.workId && fonte.workId.isNotEmpty,
      )) {
        fontiTotali.add(fonte);
      }
    }
    notifyListeners();
  }

  // Crea una context session vincolata a uno o piu' libri
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
      debugPrint('[CHAT] Errore di rete context session: ${e.message ?? e}');
      return false;
    } catch (e, stack) {
      debugPrint('[CHAT] Errore generico context session: $e\n$stack');
      return false;
    }
  }

  void resetContextSession() {
    _contextSessionId = null;
    fontiTotali.clear();
    notifyListeners();
    debugPrint('[CHAT] Context session resettata — modalità fonti libere');
  }

  void aggiungiMessaggio(MessaggioChat msg) {
    messaggi.add(msg);
    notifyListeners();
  }

  // Invia messaggio al server
  Future<MessaggioChat> inviaMessaggio(String domanda) async {
    final body = {
      'question': domanda,
      'session_id': _sessionId,
      'select_code': _selectCode,
      'top_k': 10,
      if (_contextSessionId != null) 'context_session_id': _contextSessionId,
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

      final testo =
          data['answer'] as String? ??
          data['text'] as String? ??
          data['response'] as String? ??
          'Nessuna risposta ricevuta';

      final usedBooksRaw = data['used_books'] as List? ?? [];

      final fonti = usedBooksRaw
          .map((f) => FonteChat.fromJson(f as Map<String, dynamic>))
          .toList();

      debugPrint(
        '[CHAT] Risposta ricevuta: '
        '${testo.substring(0, testo.length.clamp(0, 50))}...',
      );

      return MessaggioChat(
        testo: testo,
        isUtente: false,
        timestamp: DateTime.now(),
        fonti: fonti,
      );
    } on DioException catch (e) {
      debugPrint('[CHAT] Errore di rete invio messaggio: ${e.message ?? e}');
      throw Exception('Errore di connessione col server.');
    } catch (e, stack) {
      debugPrint('[CHAT] Errore parsing dati invio messaggio: $e\n$stack');
      throw Exception('Errore imprevisto nella lettura della risposta.');
    }
  }

  // Recupera dettagli libro tramite identifier
  Future<Map<String, dynamic>?> dettagliLibro(String identifier) async {
    try {
      final response = await _dio.get(
        '${AppConfig.chatBaseUrl}/book/$identifier',
      );
      return response.data is String
          ? jsonDecode(response.data)
          : response.data;
    } on DioException catch (e) {
      debugPrint('[CHAT] Errore rete dettagli libro: ${e.message ?? e}');
      return null;
    } catch (e, stack) {
      debugPrint('[CHAT] Errore parsing JSON dettagli libro: $e\n$stack');
      return null;
    }
  }

  // ==========================================
  // GESTIONE ROOM
  // ==========================================

  // Crea o recupera la room associata a questa sessione (POST /rooms)
  Future<String?> recuperaCodiceStanza() async {
    try {
      debugPrint('[CHAT] POST /rooms per sessione: $_sessionId');

      final response = await _dio.post(
        '${AppConfig.chatBaseUrl}/rooms',
        data: {'session_id': _sessionId},
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      final adminCode = data['admin_room_id']?.toString();

      _activeRoomCode = adminCode;
      _lastRevision = data['revision'] as int?;
      _lastUpdatedAt = data['updated_at']?.toString();

      debugPrint('[CHAT] Room creata, admin_code: $adminCode');

      return adminCode;
    } on DioException catch (e) {
      debugPrint(
        '[CHAT] Errore di rete genera codice: '
        '${e.response?.statusCode} - ${e.message}',
      );
      return null;
    } catch (e, stack) {
      debugPrint('[CHAT] Errore imprevisto genera codice: $e\n$stack');
      return null;
    }
  }

  // Legge una room con il codice (GET /rooms/{room_code}) e ripristina lo stato
  Future<bool> leggiStanza(String codice) async {
    final codiceUpper = codice.trim().toUpperCase();

    try {
      debugPrint('[CHAT] GET /rooms/$codiceUpper');
      final response = await _dio.get(
        '${AppConfig.chatBaseUrl}/rooms/$codiceUpper',
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      _sessionId = data['session_id']?.toString() ?? _sessionId;
      _activeRoomCode = codiceUpper;
      _lastRevision = data['revision'] as int?;
      _lastUpdatedAt = data['updated_at']?.toString();

      final payload = data['payload'];

      if (payload != null && payload is Map) {
        final history = payload['conversation_history'] as List? ?? [];
        messaggi.clear();

        for (var item in history) {
          if (item is Map<String, dynamic>) {
            if (item.containsKey('user') && item.containsKey('assistant')) {
              messaggi.add(
                MessaggioChat(
                  testo: item['user'].toString(),
                  isUtente: true,
                  timestamp: DateTime.now(),
                ),
              );
              messaggi.add(
                MessaggioChat(
                  testo: item['assistant'].toString(),
                  isUtente: false,
                  timestamp: DateTime.now(),
                ),
              );
            } else if (item.containsKey('question') &&
                item.containsKey('answer')) {
              messaggi.add(
                MessaggioChat(
                  testo: item['question'].toString(),
                  isUtente: true,
                  timestamp: DateTime.now(),
                ),
              );
              messaggi.add(
                MessaggioChat(
                  testo: item['answer'].toString(),
                  isUtente: false,
                  timestamp: DateTime.now(),
                ),
              );
            } else if (item.containsKey('role') &&
                item.containsKey('content')) {
              final isUtente = item['role'] == 'user';
              messaggi.add(
                MessaggioChat(
                  testo: item['content'].toString(),
                  isUtente: isUtente,
                  timestamp: DateTime.now(),
                ),
              );
            }
          }
        }

        fontiTotali.clear();
        final sources = payload['sources'] as List? ?? [];
        for (var s in sources) {
          if (s is Map<String, dynamic>) {
            fontiTotali.add(FonteChat.fromJson(s));
          }
        }
      }

      notifyListeners();
      return true;
    } on DioException catch (e) {
      debugPrint(
        '[CHAT] Errore ripristino sessione: ${e.response?.statusCode}',
      );
      return false;
    } catch (e, stack) {
      debugPrint('[CHAT] Errore parsing JSON ripristina sessione: $e\n$stack');
      return false;
    }
  }

  // --- Polling per gli aggiornamenti ---
  Future<void> controllaAggiornamenti() async {
    if (_activeRoomCode == null) return; // Nessuna stanza connessa

    try {
      String url = '${AppConfig.chatBaseUrl}/rooms/$_activeRoomCode/status';

      if (_lastRevision != null) {
        url += '?last_known_revision=$_lastRevision';
      } else if (_lastUpdatedAt != null) {
        url += '?last_known_updated_at=$_lastUpdatedAt';
      }

      final response = await _dio.get(url);
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (data['has_updates'] == true) {
        debugPrint(
          '[POLLING] Nuovi messaggi rilevati nella stanza $_activeRoomCode. '
          'Scaricamento in corso...',
        );
        await leggiStanza(_activeRoomCode!);
      }
    } catch (e) {
      debugPrint('[POLLING] Errore silenzioso: $e');
    }
  }
}
