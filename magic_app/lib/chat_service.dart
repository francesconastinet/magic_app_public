import 'dart:convert';
import 'dart:math' as math; // TODO: rimuovere quando disponibile api
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'app_config.dart';

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

  List<MessaggioChat> messaggi = [];
  List<FonteChat> fontiTotali = [];

  // Mappa statica per simulare il database del server
  // TODO: rimuovere quando disponibile api
  static final Map<String, Map<String, dynamic>> _mockDbSessioni = {};

  String get sessionId => _sessionId;
  String? get contextSessionId => _contextSessionId;

  void aggiungiMessaggio(MessaggioChat msg) {
    messaggi.add(msg);
    notifyListeners();
  }

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

  // POST /chat/session/share
  // TODO: modificare quando disponibile api
  Future<String?> generaCodiceCondivisione() async {
    if (messaggi.isEmpty) return null;

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = math.Random();
    final codice = String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );

    _mockDbSessioni[codice] = {
      'session_id': _sessionId,
      'context_session_id': _contextSessionId,
      'history': List<MessaggioChat>.from(messaggi),
    };

    return codice;
  }

  // POST /chat/session/restore
  // TODO: modificare quando disponibile api
  Future<bool> ripristinaSessione(String codice) async {
    final codiceUpper = codice.toUpperCase();

    if (!_mockDbSessioni.containsKey(codiceUpper)) return false;

    final dati = _mockDbSessioni[codiceUpper]!;

    _sessionId = dati['session_id'];
    _contextSessionId = dati['context_session_id'];
    messaggi = List<MessaggioChat>.from(dati['history']);

    fontiTotali.clear();
    for (var msg in messaggi) {
      aggiornaFonti(msg.fonti);
    }

    notifyListeners();
    return true;
  }

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
      debugPrint('[CHAT] Errore di rete context session: ${e.message ?? e}');
      return false;
    } catch (e, stack) {
      debugPrint('[CHAT] Errore generico context session: $e\n$stack');
      return false;
    }
  }

  // Torna a fonti libere
  void resetContextSession() {
    _contextSessionId = null;
    debugPrint('[CHAT] Context session resettata — modalità fonti libere');
  }

  // Invia messaggio al server
  // POST /query con question, session_id, select_code
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
      debugPrint('[CHAT] Libri usati: ${fonti.map((f) => f.title).join(', ')}');

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
      debugPrint('[CHAT] Errore rete dettagli libro: ${e.message ?? e}');
      return null;
    } catch (e, stack) {
      debugPrint('[CHAT] Errore parsing JSON dettagli libro: $e\n$stack');
      return null;
    }
  }
}
