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

  String? _activeRoomCode;
  int? _lastRevision;
  String? _lastUpdatedAt;
  String _role = 'admin';
  String? _adminRoomId;
  String? _guestRoomId;

  List<MessaggioChat> messaggi = [];
  List<FonteChat> fontiTotali = [];

  // --- STATO DEL CONTESTO ---
  List<String> _activeBookIds = [];
  bool _isContextLocked = false;

  String get sessionId => _sessionId;
  bool get isGuest => _role == 'guest';
  bool get isRoomActive => _activeRoomCode != null;

  // Getter esposti per la UI
  List<String> get activeBookIds => _activeBookIds;
  bool get isContextLocked => _isContextLocked;

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

  // --- RECUPERA STATO CONTESTO ---
  Future<void> recuperaStatoContesto() async {
    try {
      debugPrint('[CHAT] GET /chat/context-sessions/$_sessionId');
      final response = await _dio.get(
        '${AppConfig.chatBaseUrl}/chat/context-sessions/$_sessionId',
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      _activeBookIds = List<String>.from(data['active_book_ids'] ?? []);
      _isContextLocked = data['is_locked'] ?? false;
      notifyListeners();
    } on DioException catch (e) {
      debugPrint(
        '[CHAT] Nessun contesto attivo o errore GET: ${e.response?.statusCode}',
      );
    }
  }

  // --- MODIFICA STATO CONTESTO ---
  Future<bool> _patchContextSession(Map<String, dynamic> body) async {
    try {
      debugPrint('[CHAT] PATCH /chat/context-sessions/$_sessionId: $body');

      final response = await _dio.patch(
        '${AppConfig.chatBaseUrl}/chat/context-sessions/$_sessionId',
        data: body,
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      _activeBookIds = List<String>.from(data['active_book_ids'] ?? []);
      _isContextLocked = data['is_locked'] ?? false;

      notifyListeners();
      return true;
    } on DioException catch (e) {
      debugPrint(
        '[CHAT] Errore PATCH context session: ${e.response?.data ?? e.message}',
      );
      return false;
    } catch (e, stack) {
      debugPrint('[CHAT] Errore generico PATCH context session: $e\n$stack');
      return false;
    }
  }

  // --- AZIONI SUL CONTESTO ---

  // Sostituisce integralmente le fonti
  Future<bool> creaContextSession(List<String> bookIds) async {
    return await _patchContextSession({
      'action': 'replace',
      'book_ids': bookIds,
    });
  }

  // Aggiunge nuove fonti a quelle esistenti
  Future<bool> aggiungiFontiContesto(List<String> bookIds) async {
    return await _patchContextSession({'action': 'add', 'book_ids': bookIds});
  }

  // Rimuove specifiche fonti
  Future<bool> rimuoviFontiContesto(List<String> bookIds) async {
    return await _patchContextSession({
      'action': 'remove',
      'book_ids': bookIds,
    });
  }

  // Blocca o sblocca esplicitamente il contesto
  Future<bool> impostaBloccoContesto(bool isLocked) async {
    return await _patchContextSession({
      'action': 'toggle_lock',
      'is_locked': isLocked,
    });
  }

  // Resetta il contesto svuotando i book_ids
  Future<void> resetContextSession() async {
    fontiTotali.clear();
    await _patchContextSession({'action': 'replace', 'book_ids': []});
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

  // --- RECUPERA ROOM SESSIONE ---
  Future<Map<String, String?>?> recuperaCodiceStanza() async {
    if (_role == 'guest') {
      debugPrint(
        '[CHAT] Utente Guest: accesso admin bloccato. '
        'Condivisione limitata al codice guest.',
      );
      return {'admin': null, 'guest': _activeRoomCode, 'role': 'guest'};
    }

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
      final guestCode = data['guest_room_id']?.toString();
      final role = data['role']?.toString() ?? 'admin';

      if (role == 'guest') {
        _role = 'guest';
        _activeRoomCode = guestCode;
        _guestRoomId = guestCode;

        notifyListeners();
        return {'admin': null, 'guest': guestCode, 'role': 'guest'};
      }

      _activeRoomCode = adminCode ?? guestCode;
      _adminRoomId = (adminCode != null && adminCode.isNotEmpty)
          ? adminCode
          : null;
      _guestRoomId = (guestCode != null && guestCode.isNotEmpty)
          ? guestCode
          : null;
      _role = role;
      _lastRevision = data['revision'] as int?;
      _lastUpdatedAt = data['updated_at']?.toString();

      debugPrint(
        '[CHAT] Room creata, admin: $_adminRoomId, guest: $_guestRoomId',
      );

      await recuperaStatoContesto();

      return {'admin': _adminRoomId, 'guest': _guestRoomId, 'role': _role};
    } on DioException catch (e) {
      debugPrint(
        '[CHAT] Errore di rete genera codice: ${e.response?.statusCode}',
      );
      return null;
    } catch (e, stack) {
      debugPrint('[CHAT] Errore imprevisto genera codice: $e\n$stack');
      return null;
    }
  }

  // --- LEGGE ROOM SESSIONE ---
  Future<bool> leggiStanza(String codice, {bool isPolling = false}) async {
    final codiceUpper = codice.trim().toUpperCase();

    if (!isPolling) {
      if (codiceUpper == _activeRoomCode ||
          codiceUpper == _adminRoomId ||
          codiceUpper == _guestRoomId) {
        debugPrint(
          '[CHAT] Il codice inserito appartiene già alla stanza attiva. '
          'Ignorato.',
        );
        return true;
      }
    }

    try {
      debugPrint('[CHAT] GET /rooms/$codiceUpper');
      final response = await _dio.get(
        '${AppConfig.chatBaseUrl}/rooms/$codiceUpper',
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      final fetchedSessionId = data['session_id']?.toString();
      final fetchedRole = data['role']?.toString() ?? 'guest';

      if (!isPolling &&
          fetchedSessionId != null &&
          fetchedSessionId == _sessionId) {
        if (_role == 'admin' && fetchedRole == 'guest') {
          debugPrint(
            '[CHAT] Tentativo di downgrade ad Admin -> '
            'Guest nella stessa sessione ignorato.',
          );
          _guestRoomId ??= data['guest_room_id']?.toString();
          return true;
        }

        if (_role == fetchedRole) {
          debugPrint(
            '[CHAT] Stanza già attiva con il medesimo ruolo. Ignorato.',
          );
          return true;
        }
      }

      _sessionId = fetchedSessionId ?? _sessionId;
      _activeRoomCode = codiceUpper;

      _role = fetchedRole;

      final adminCode = data['admin_room_id']?.toString();
      final guestCode = data['guest_room_id']?.toString();
      _adminRoomId = (adminCode != null && adminCode.isNotEmpty)
          ? adminCode
          : null;
      _guestRoomId = (guestCode != null && guestCode.isNotEmpty)
          ? guestCode
          : null;

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

      await recuperaStatoContesto();

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

  // --- POLLING AGGIORNAMENTI ---
  Future<void> controllaAggiornamenti() async {
    if (_activeRoomCode == null) return;

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
        await leggiStanza(_activeRoomCode!, isPolling: true);
      }
    } catch (e) {
      debugPrint('[POLLING] Errore silenzioso: $e');
    }
  }
}
