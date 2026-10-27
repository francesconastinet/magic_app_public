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

  // --- COLLEZIONE DELLA CONVERSAZIONE ---
  // la stanza e' legata a una collezione: se nella /query arriva un
  // collection_id diverso il server risponde 409 "Collezione diversa dalla
  // stanza". Si tiene quindi la collezione usata nella conversazione (ultima
  // domanda andata a buon fine) e quella della stanza, per mandarle sempre
  // uguali in POST /rooms e nelle domande fatte nella stanza.
  String? _collectionIdConversazione;
  String? _collectionIdStanza;
  // collezione dei libri del contesto scelto (fonte bloccata). La imposta
  // il ChatViewModel quando cambia il contesto o prima di ogni domanda.
  String? _collectionIdContesto;

  // il servizio chat accetta solo collection_id in formato UUID
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  List<MessaggioChat> messaggi = [];
  List<FonteChat> fontiTotali = [];

  // --- STATO DEL CONTESTO ---
  List<String> _activeBookIds = [];
  bool _isContextLocked = false;

  // secondo tentativo automatico quando la connessione cade (es. la
  // VPN si disconnette per qualche secondo). Si riprova solo se la richiesta
  // non e' arrivata al server (errore di connessione o timeout di connessione),
  // quindi non c'e' rischio di mandare due volte la stessa domanda: il
  // request_id della /query e' lo stesso anche nel secondo tentativo.
  static const int _tentativiExtra = 1;
  static const Duration _attesaTentativo = Duration(seconds: 3);

  ChatService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          final fatti = (e.requestOptions.extra['tentativi_extra'] as int?) ?? 0;
          final isErroreConnessione =
              e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout;

          if (isErroreConnessione && fatti < _tentativiExtra) {
            debugPrint(
              '[CHAT] Connessione assente (${e.requestOptions.method} '
              '${e.requestOptions.uri.path}): nuovo tentativo tra '
              '${_attesaTentativo.inSeconds} secondi',
            );
            await Future.delayed(_attesaTentativo);

            try {
              e.requestOptions.extra['tentativi_extra'] = fatti + 1;
              final response = await _dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } on DioException catch (e2) {
              return handler.next(e2);
            }
          }

          return handler.next(e);
        },
      ),
    );
  }

  String get sessionId => _sessionId;
  bool get isGuest => _role == 'guest';
  bool get isRoomActive => _activeRoomCode != null;
  List<String> get activeBookIds => _activeBookIds;
  bool get isContextLocked => _isContextLocked;

  // ==========================================
  // SCOPE ED ERRORI (nuove API del servizio chat)
  // ==========================================

  // il tenant_id e' obbligatorio in tutte le chiamate. Nei GET e nelle
  // PATCH va in query string; in /query e in POST /rooms va nel body.
  Map<String, dynamic> get _scope => {'tenant_id': AppConfig.tenantId};

  //  codice admin da mandare come room_code. Esiste solo se la stanza
  // e' stata creata e l'utente non e' guest (il guest e' in sola lettura).
  String? get _roomCodeAdmin =>
      (!isGuest && _adminRoomId != null && _adminRoomId!.isNotEmpty)
      ? _adminRoomId
      : null;

  // legge il collection_id dalla risposta delle API stanze (campo
  // collection_id in cima o dentro payload). Ritorna null se non c'e'.
  String? _collezioneDaRisposta(dynamic data) {
    if (data is! Map) return null;
    String? pulisci(dynamic v) {
      final s = v?.toString().trim();
      return (s != null && s.isNotEmpty && s != 'null') ? s : null;
    }

    final diretto = pulisci(data['collection_id']);
    if (diretto != null) return diretto;
    final payload = data['payload'];
    if (payload is Map) return pulisci(payload['collection_id']);
    return null;
  }

  // ritorna il valore pulito se e' un UUID valido, altrimenti null (e lo
  // scrive nel log, cosi' si vede da dove arriva il valore sbagliato)
  String? _uuidValido(String? valore) {
    final v = valore?.trim();
    if (v == null || v.isEmpty) return null;
    if (_uuidRegex.hasMatch(v)) return v;
    debugPrint('[CHAT] collection_id non valido, non viene mandato: "$v"');
    return null;
  }

  // collection_id da mandare al server: solo con fonte bloccata (contesto
  // bloccato con almeno un libro) e solo se e' un UUID valido
  String? get _collezioneFonteBloccata {
    if (!_isContextLocked || _activeBookIds.isEmpty) return null;
    return _uuidValido(_collectionIdContesto);
  }

  // il ChatViewModel imposta qui la collezione dei libri in fonte bloccata
  // (null se i libri sono di collezioni diverse o si e' in fonti libere)
  void impostaCollezioneContesto(String? collectionId) {
    _collectionIdContesto = collectionId;
    debugPrint('[CHAT] Collezione del contesto: $_collectionIdContesto');
  }

  // messaggi per gli errori HTTP documentati dal servizio chat.
  // Ritorna null per gli altri codici, cosi' resta il messaggio di prima.
  String? _messaggioDaStatus(int? status) {
    switch (status) {
      case 403:
        return 'Non hai i permessi per scrivere in questa stanza. '
            'Se sei ospite, duplica la stanza per continuare.';
      case 409:
        return 'La conversazione appartiene a un altro ambito. '
            'Avvia una nuova chat.';
      case 410:
        return 'Il contesto delle fonti e\' scaduto. Riseleziona le fonti.';
      case 413:
        return 'Hai selezionato troppe fonti.';
      case 422:
        return 'Richiesta non valida. Controlla la configurazione del tenant.';
      case 503:
        return 'Il server sta salvando il contesto. Riprova tra qualche istante.';
      default:
        return null;
    }
  }

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

  Future<void> recuperaStatoContesto() async {
    try {
      debugPrint('[CHAT] GET /chat/context-sessions/$_sessionId');
      final response = await _dio.get(
        '${AppConfig.chatBaseUrl}/chat/context-sessions/$_sessionId',
        queryParameters: _scope,
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      _activeBookIds = List<String>.from(data['active_book_ids'] ?? []);
      _isContextLocked = data['is_locked'] ?? false;
      debugPrint(
        '[CHAT] Contesto sul server (GET): libri attivi=$_activeBookIds, '
        'bloccato=$_isContextLocked',
      );
      notifyListeners();
    } on DioException catch (e) {
      debugPrint(
        '[CHAT] Nessun contesto attivo o errore GET: ${e.response?.statusCode}',
      );
    }
  }

  Future<bool> _patchContextSession(Map<String, dynamic> body) async {
    try {
      //  — per i contesti collegati a una stanza serve il room_code admin
      // nel body (se la stanza non esiste ancora, o siamo guest, non si manda).
      final bodyConStanza = {
        ...body,
        if (_roomCodeAdmin != null) 'room_code': _roomCodeAdmin,
      };

      debugPrint(
        '[CHAT] PATCH /chat/context-sessions/$_sessionId: $bodyConStanza',
      );

      final response = await _dio.patch(
        '${AppConfig.chatBaseUrl}/chat/context-sessions/$_sessionId',
        data: bodyConStanza,
        queryParameters: _scope,
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      _activeBookIds = List<String>.from(data['active_book_ids'] ?? []);
      _isContextLocked = data['is_locked'] ?? false;

      debugPrint(
        '[CHAT] Contesto dopo PATCH: libri attivi=$_activeBookIds, '
        'bloccato=$_isContextLocked',
      );

      notifyListeners();
      return true;
    } on DioException catch (e) {
      final responseData = e.response?.data;

      if (responseData is Map && responseData['detail'] != null) {
        final detail = responseData['detail'];

        if (detail is Map && detail['message'] != null) {
          throw Exception(detail['message']);
        }
      }
      debugPrint(
        '[CHAT] Errore PATCH context session: ${e.response?.data ?? e.message}',
      );
      return false;
    } catch (e, stack) {
      debugPrint('[CHAT] Errore generico PATCH context session: $e\n$stack');
      return false;
    }
  }

  Future<bool> creaContextSession(List<String> bookIds) async {
    return await _patchContextSession({
      'action': 'replace',
      'book_ids': bookIds,
    });
  }

  Future<bool> aggiungiFontiContesto(List<String> bookIds) async {
    return await _patchContextSession({'action': 'add', 'book_ids': bookIds});
  }

  Future<bool> rimuoviFontiContesto(List<String> bookIds) async {
    return await _patchContextSession({
      'action': 'remove',
      'book_ids': bookIds,
    });
  }

  Future<bool> impostaBloccoContesto(bool isLocked) async {
    return await _patchContextSession({
      'action': 'toggle_lock',
      'is_locked': isLocked,
    });
  }

  Future<void> resetContextSession() async {
    fontiTotali.clear();
    await _patchContextSession({'action': 'replace', 'book_ids': []});

    // senza libri il lucchetto non deve restare attivo: con il contesto
    // bloccato e vuoto il server risponde 400 "Seleziona almeno un libro nel
    // contesto manuale" a ogni domanda. Si sblocca per tornare alle fonti libere.
    if (_isContextLocked) {
      await _patchContextSession({'action': 'toggle_lock', 'is_locked': false});
    }

    debugPrint('[CHAT] Context session resettata — modalità fonti libere');
  }

  // "Nuova chat": riparte da zero con una sessione nuova (nuovo session_id),
  // senza messaggi, fonti, contesto e stanza. La sessione di prima resta sul
  // server (le sessioni di contesto scadono da sole) e non viene toccata.
  void nuovaChat() {
    final sessionePrecedente = _sessionId;

    _sessionId = const Uuid().v4();
    messaggi = [];
    fontiTotali = [];
    _activeBookIds = [];
    _isContextLocked = false;
    _activeRoomCode = null;
    _adminRoomId = null;
    _guestRoomId = null;
    _role = 'admin';
    _lastRevision = null;
    _lastUpdatedAt = null;
    _collectionIdConversazione = null;
    _collectionIdStanza = null;
    _collectionIdContesto = null;

    debugPrint(
      '[CHAT] Nuova chat: sessione $sessionePrecedente chiusa, '
      'nuova sessione $_sessionId',
    );
    notifyListeners();
  }

  void aggiungiMessaggio(MessaggioChat msg) {
    messaggi.add(msg);
    notifyListeners();
  }

  // collection_id facoltativo: si passa solo se si vuole limitare la domanda
  // a una collezione. Se e' null (o vuoto) non viene mandato e il chatbot
  // risponde su tutto, senza obbligo di selezionare una collezione.
  Future<MessaggioChat> inviaMessaggio(
    String domanda, {
    String? collectionId,
  }) async {
    // la stanza si usa solo quando e' gia' attiva, cioe' creata dalla
    // scansione del libro per la condivisione. In chat libera / modalita'
    // smart non si crea nessuna stanza e non si manda il room_code.
    if (isRoomActive) {
      //  — si scrive in una stanza solo con il codice
      // admin, quindi la stanza va creata prima della prima domanda.
      await _assicuraStanza();
    }

    // il collection_id si prende sempre dalla collezione dei libri in fonte
    // bloccata (contesto scelto). Se arriva un valore nuovo lo si salva come
    // collezione del contesto, cosi' la usa anche POST /rooms.
    if (collectionId != null) _collectionIdContesto = collectionId;

    // si manda solo con fonte bloccata e solo se e' un UUID valido: in chat
    // libera non si manda, e un valore non valido darebbe 422
    // "collection_id deve essere un UUID valido".
    // (righe precedenti: nella stanza si usava la collezione della stanza
    //   final collezione = isRoomActive
    //       ? (_collectionIdStanza ?? _collectionIdConversazione ?? richiesta)
    //       : richiesta;)
    final collezione = _collezioneFonteBloccata;
    final haCollezione = collezione != null;

    if (_collectionIdStanza != null &&
        collezione != null &&
        collezione != _collectionIdStanza) {
      debugPrint(
        '[CHAT] Collezione della fonte bloccata ($collezione) diversa da '
        'quella della stanza ($_collectionIdStanza)',
      );
    }

    final Map<String, dynamic> body = isRoomActive
        ? {
            'question': domanda,
            'session_id': _sessionId,
            'select_code': _selectCode,
            'top_k': 10,
            //  — il servizio RAG vuole sempre il tenant_id nel body della
            // /query (di default e' il tenant Magic, vedi AppConfig.tenantId).
            'tenant_id': AppConfig.tenantId,
            //  — codice admin della stanza (se esiste) e ID univoco del turno.
            if (_roomCodeAdmin != null) 'room_code': _roomCodeAdmin,
            'request_id': const Uuid().v4(),
            if (haCollezione) 'collection_id': collezione,
          }
        : {
            // chat libera / modalita' smart: solo i campi obbligatori
            // (tenant_id, question, session_id) e collection_id se presente.
            'tenant_id': AppConfig.tenantId,
            'question': domanda,
            'session_id': _sessionId,
            if (haCollezione) 'collection_id': collezione,
          };

    debugPrint(
      '[CHAT] POST /query (${isRoomActive ? 'stanza' : 'chat libera'}): $body',
    );

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

      // collezione usata in questa conversazione, da mandare uguale quando
      // si crea la stanza (condividi / scansione)
      _collectionIdConversazione = haCollezione ? collezione : null;

      return MessaggioChat(
        testo: testo,
        isUtente: false,
        timestamp: DateTime.now(),
        fonti: fonti,
      );
    } on DioException catch (e) {
      debugPrint('[CHAT] Errore di rete invio messaggio: ${e.message ?? e}');
      final status = e.response?.statusCode;
      if (status != null) {
        debugPrint('[CHAT] Risposta $status: ${e.response?.data}');
      }

      // per il 400 e il 422 si mostra il testo vero mandato dal server (es.
      // "Seleziona una collezione prima di interrogare la stanza") al posto
      // del messaggio generico. Se il detail non e' una stringa (es. l'elenco
      // degli errori di validazione) resta il messaggio di prima.
      final datiErrore = e.response?.data;
      final dettaglioServer = (datiErrore is Map) ? datiErrore['detail'] : null;
      if ((status == 400 || status == 422) &&
          dettaglioServer is String &&
          dettaglioServer.trim().isNotEmpty) {
        throw Exception(dettaglioServer.trim());
      }

      throw Exception(
        _messaggioDaStatus(status) ?? 'Errore di connessione col server.',
      );
    } catch (e, stack) {
      debugPrint('[CHAT] Errore parsing dati invio messaggio: $e\n$stack');
      throw Exception('Errore imprevisto nella lettura della risposta.');
    }
  }

  Future<Map<String, dynamic>?> dettagliLibro(String identifier) async {
    try {
      final response = await _dio.get(
        '${AppConfig.chatBaseUrl}/book/${Uri.encodeComponent(identifier)}',
        queryParameters: _scope,
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

  //  — crea la stanza prima della prima domanda (se non c'e' ancora e non
  // siamo guest) e conserva i codici. Non attiva la stanza (_activeRoomCode)
  // e non cambia la UI: serve solo ad avere il room_code admin per la /query.
  // Se la creazione fallisce si prosegue senza stanza, come una chat normale.
  Future<void> _assicuraStanza() async {
    if (isGuest || _adminRoomId != null) return;

    try {
      debugPrint('[CHAT] POST /rooms (prima della query) per sessione: $_sessionId');
      final response = await _dio.post(
        '${AppConfig.chatBaseUrl}/rooms',
        data: {
          'session_id': _sessionId,
          'tenant_id': AppConfig.tenantId,
          // collezione dei libri in fonte bloccata, cosi' la stanza nasce
          // legata alla collezione giusta (evita il 409)
          if (_collezioneFonteBloccata != null)
            'collection_id': _collezioneFonteBloccata,
        },
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      _collectionIdStanza =
          _collezioneDaRisposta(data) ?? _collezioneFonteBloccata;

      if ((data['role']?.toString() ?? 'admin') == 'guest') return;

      final adminCode = data['admin_room_id']?.toString();
      final guestCode = data['guest_room_id']?.toString();

      if (adminCode != null && adminCode.isNotEmpty) _adminRoomId = adminCode;
      if (guestCode != null && guestCode.isNotEmpty) _guestRoomId = guestCode;

      debugPrint(
        '[CHAT] Room creata prima della query, admin: $_adminRoomId, '
        'guest: $_guestRoomId',
      );
    } on DioException catch (e) {
      debugPrint(
        '[CHAT] Errore creazione room prima della query: '
        '${e.response?.statusCode} ${e.response?.data}',
      );
    } catch (e, stack) {
      debugPrint('[CHAT] Errore imprevisto creazione room: $e\n$stack');
    }
  }

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
        data: {
          'session_id': _sessionId,
          //  tenant_id obbligatorio nel body; se la stanza esiste gia'
          // serve il codice admin, altrimenti il server risponde 403.
          'tenant_id': AppConfig.tenantId,
          if (_roomCodeAdmin != null) 'room_code': _roomCodeAdmin,
          // la stanza va creata con la collezione dei libri in fonte
          // bloccata: se no le domande successive tornano 409
          // "Collezione diversa dalla stanza"
          if (_collezioneFonteBloccata != null)
            'collection_id': _collezioneFonteBloccata,
        },
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      _collectionIdStanza =
          _collezioneDaRisposta(data) ?? _collezioneFonteBloccata;
      debugPrint(
        '[CHAT] Collezione della stanza: $_collectionIdStanza '
        '(conversazione: $_collectionIdConversazione)',
      );

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
        '[CHAT] Errore di rete genera codice: ${e.response?.statusCode} '
        '${e.response?.data}',
      );
      return null;
    } catch (e, stack) {
      debugPrint('[CHAT] Errore imprevisto genera codice: $e\n$stack');
      return null;
    }
  }

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
      if (!isPolling) debugPrint('[CHAT] GET /rooms/$codiceUpper');

      final response = await _dio.get(
        '${AppConfig.chatBaseUrl}/rooms/$codiceUpper',
        queryParameters: _scope,
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
            '[CHAT] Tentativo di downgrade ad Admin -> Guest ignorato.',
          );
          _guestRoomId ??= data['guest_room_id']?.toString();
          return true;
        }
        if (_role == fetchedRole) return true;
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

      // collezione della stanza aperta da codice (se il server la manda)
      final collezioneStanza = _collezioneDaRisposta(data);
      if (collezioneStanza != null) {
        _collectionIdStanza = collezioneStanza;
        _collectionIdConversazione = collezioneStanza;
      }

      final payload = data['payload'];

      if (payload != null && payload is Map) {
        var history = payload['conversation_history'] as List? ?? [];
        //  nelle nuove API payload.messages e' la stessa conversazione
        // di conversation_history: si usa solo se questa è vuota (mai
        // entrambe, altrimenti i messaggi sarebbero duplicati).
        if (history.isEmpty) history = payload['messages'] as List? ?? [];

        List<MessaggioChat> unmatchedLocal = List.from(messaggi);
        List<MessaggioChat> nuoviMessaggi = [];

        MessaggioChat trovaOCrea(String testo, bool isUtente) {
          final index = unmatchedLocal.indexWhere(
            (m) => m.isUtente == isUtente && m.testo == testo,
          );
          if (index != -1) {
            return unmatchedLocal.removeAt(index);
          } else {
            return MessaggioChat(
              testo: testo,
              isUtente: isUtente,
              timestamp: DateTime.now(),
            );
          }
        }

        for (var item in history) {
          if (item is Map<String, dynamic>) {
            if (item.containsKey('user') && item.containsKey('assistant')) {
              nuoviMessaggi.add(trovaOCrea(item['user'].toString(), true));
              nuoviMessaggi.add(
                trovaOCrea(item['assistant'].toString(), false),
              );
            } else if (item.containsKey('question') &&
                item.containsKey('answer')) {
              nuoviMessaggi.add(trovaOCrea(item['question'].toString(), true));
              nuoviMessaggi.add(trovaOCrea(item['answer'].toString(), false));
            } else if (item.containsKey('role') &&
                item.containsKey('content')) {
              final isUtente = item['role'] == 'user';
              nuoviMessaggi.add(
                trovaOCrea(item['content'].toString(), isUtente),
              );
            }
          }
        }

        nuoviMessaggi.addAll(unmatchedLocal);
        nuoviMessaggi.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        messaggi = nuoviMessaggi;

        List<FonteChat> unmatchedFonti = List.from(fontiTotali);
        List<FonteChat> nuoveFonti = [];
        final sources = payload['sources'] as List? ?? [];

        for (var s in sources) {
          if (s is Map<String, dynamic>) {
            final f = FonteChat.fromJson(s);
            final index = unmatchedFonti.indexWhere(
              (u) => u.identifier == f.identifier,
            );
            if (index != -1) {
              nuoveFonti.add(unmatchedFonti.removeAt(index));
            } else {
              nuoveFonti.add(f);
            }
          }
        }
        nuoveFonti.addAll(unmatchedFonti);
        fontiTotali = nuoveFonti;
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

  //  il guest e' in sola lettura: per continuare a scrivere deve
  // duplicare la stanza (POST /rooms/{codice}/fork). La copia ha una nuova
  // sessione e nuovi codici admin/guest, e da quel momento si lavora su quella.
  Future<Map<String, String?>?> duplicaStanza() async {
    final codice = _activeRoomCode;
    if (codice == null) return null;

    try {
      debugPrint('[CHAT] POST /rooms/$codice/fork');
      final response = await _dio.post(
        '${AppConfig.chatBaseUrl}/rooms/$codice/fork',
        queryParameters: _scope,
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      final nuovaSessione = data['session_id']?.toString();
      final adminCode = data['admin_room_id']?.toString();
      final guestCode = data['guest_room_id']?.toString();

      if (nuovaSessione != null && nuovaSessione.isNotEmpty) {
        _sessionId = nuovaSessione;
      }
      _role = data['role']?.toString() ?? 'admin';
      _adminRoomId = (adminCode != null && adminCode.isNotEmpty)
          ? adminCode
          : null;
      _guestRoomId = (guestCode != null && guestCode.isNotEmpty)
          ? guestCode
          : null;
      _activeRoomCode = _adminRoomId ?? _guestRoomId;
      _lastRevision = data['revision'] as int?;
      _lastUpdatedAt = data['updated_at']?.toString();

      // la copia mantiene la collezione della stanza originale
      _collectionIdStanza = _collezioneDaRisposta(data) ?? _collectionIdStanza;

      debugPrint(
        '[CHAT] Room duplicata, admin: $_adminRoomId, guest: $_guestRoomId',
      );

      await recuperaStatoContesto();
      notifyListeners();
      return {'admin': _adminRoomId, 'guest': _guestRoomId, 'role': _role};
    } on DioException catch (e) {
      debugPrint(
        '[CHAT] Errore duplicazione room: ${e.response?.statusCode} '
        '${e.response?.data}',
      );
      return null;
    } catch (e, stack) {
      debugPrint('[CHAT] Errore imprevisto duplicazione room: $e\n$stack');
      return null;
    }
  }

  Future<void> controllaAggiornamenti() async {
    if (_activeRoomCode == null) return;

    try {
      final url = '${AppConfig.chatBaseUrl}/rooms/$_activeRoomCode/status';

      // tenant_id + revisione (o data di aggiornamento) in query
      // string; Dio si occupa dell'encoding del timestamp.
      final params = <String, dynamic>{..._scope};
      if (_lastRevision != null) {
        params['last_known_revision'] = _lastRevision;
      } else if (_lastUpdatedAt != null) {
        params['last_known_updated_at'] = _lastUpdatedAt;
      }

      final response = await _dio.get(url, queryParameters: params);
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
      debugPrint('[POLLING] Timeout aggiornamento: $e');
    }
  }
}