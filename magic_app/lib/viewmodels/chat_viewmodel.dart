import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/chat_service.dart';
import '../data/catalogue_repository.dart';

class ChatViewModel extends ChangeNotifier {
  // --- DIPENDENZE ---
  final ChatService _chatService;
  final CatalogueRepository _catalogueRepo;

  // --- STATO ---
  bool botStaScrivendo = false;
  bool contextSessionInCorso = false;
  Timer? _pollingTimer;

  // --- GETTER ---
  List<MessaggioChat> get messaggi => _chatService.messaggi;
  List<FonteChat> get fontiTotali => _chatService.fontiTotali;

  bool get contextSessionCreata => _chatService.activeBookIds.isNotEmpty;
  bool get isContextLocked => _chatService.isContextLocked;
  bool get isGuest => _chatService.isGuest;
  bool get isRoomActive => _chatService.isRoomActive;
  List<String> get activeBookIds => _chatService.activeBookIds;

  String? get titoloContesto {
    final ids = _chatService.activeBookIds;
    if (ids.isEmpty) return null;

    if (ids.length == 1) {
      try {
        return _catalogueRepo.libri.firstWhere((b) => b.id == ids.first).titolo;
      } catch (_) {
        return 'Manoscritto Selezionato';
      }
    }

    // i libri di una collezione ora sono quelli con collection_id uguale
    // all'id della collezione (non piu' la lista bookIds della collezione)
    // (righe originali:
    //   if (coll.bookIds.length == ids.length &&
    //       coll.bookIds.every((id) => ids.contains(id))) {
    //     return coll.name;
    //   })
    for (var coll in _catalogueRepo.collezioni) {
      final idsCollezione = _catalogueRepo.libri
          .where((b) => b.collectionId == coll.id)
          .map((b) => b.id)
          .toList();
      if (idsCollezione.length == ids.length &&
          idsCollezione.every((id) => ids.contains(id))) {
        return coll.name;
      }
    }

    return 'Manoscritti vari';
  }

  // collection_id da mandare nella /query: si prende dai libri del contesto
  // attivo. Se tutti appartengono alla stessa collezione si manda quell'id,
  // altrimenti (nessun libro, libri di collezioni diverse o senza collezione)
  // resta null e il chatbot risponde su tutto (collection_id facoltativo).
  String? get _collectionIdContesto {
    final ids = _chatService.activeBookIds;
    if (ids.isEmpty) return null;

    String? idComune;
    for (final id in ids) {
      String? idCollezioneLibro;
      for (final b in _catalogueRepo.libri) {
        if (b.id == id) {
          idCollezioneLibro = b.collectionId;
          break;
        }
      }

      if (idCollezioneLibro == null || idCollezioneLibro.isEmpty) return null;
      if (idComune == null) {
        idComune = idCollezioneLibro;
      } else if (idComune != idCollezioneLibro) {
        return null;
      }
    }
    return idComune;
  }

  // --- EVENTI UI ---
  VoidCallback? onScrollToBottom;
  void Function(String)? onShowError;

  ChatViewModel({required this._chatService, required this._catalogueRepo}) {
    _chatService.addListener(_onServiceUpdate);

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _chatService.controllaAggiornamenti();
    });
  }

  void _onServiceUpdate() {
    notifyListeners();
  }

  @override
  void dispose() {
    _chatService.removeListener(_onServiceUpdate);
    _pollingTimer?.cancel();
    super.dispose();
  }

  // --- LOGICA ---

  void inizializza(List<String>? ids, String? titolo) {
    if (ids != null && ids.isNotEmpty) {
      _inizializzaContextSession(ids);
    }
  }

  Future<void> aggiornaContesto(
    List<String>? nuoviIds,
    String? nuovoTitolo,
  ) async {
    final setNuovi = (nuoviIds ?? []).toSet();
    final setAttuali = _chatService.activeBookIds.toSet();

    if (setNuovi.length == setAttuali.length &&
        setNuovi.containsAll(setAttuali)) {
      return;
    }

    if (setNuovi.isNotEmpty) {
      await _inizializzaContextSession(nuoviIds!);
    } else {
      await _impostaModalitaSmart();
    }
  }

  Future<void> _impostaModalitaSmart() async {
    contextSessionInCorso = true;
    notifyListeners();

    // NUOVO — se la richiesta lancia un'eccezione la rotella non deve restare
    // accesa per sempre: si logga l'errore e si prosegue.
    try {
      await _chatService.resetContextSession();
    } catch (e) {
      debugPrint('[CHAT] Errore reset contesto (modalità smart): $e');
    }

    // fonti libere: nessuna collezione da mandare
    _chatService.impostaCollezioneContesto(null);

    contextSessionInCorso = false;
    notifyListeners();
    onScrollToBottom?.call();
  }

  Future<void> _inizializzaContextSession(List<String> ids) async {
    contextSessionInCorso = true;
    notifyListeners();

    // NUOVO — il service lancia un'eccezione quando il server risponde con un
    // messaggio di errore (es. "Nessun id valido trovato"): prima non veniva
    // catturata e la rotella restava accesa. Ora conta come tentativo fallito.
    bool successo = false;
    try {
      successo = await _chatService.creaContextSession(ids);

      if (successo) {
        successo = await _chatService.impostaBloccoContesto(true);
      }
    } catch (e) {
      debugPrint('[CHAT] Errore creazione contesto: $e');
      successo = false;
    }

    contextSessionInCorso = false;

    // collezione dei libri appena messi in fonte bloccata (null se sono di
    // collezioni diverse o se la creazione del contesto e' fallita)
    _chatService.impostaCollezioneContesto(
      successo ? _collectionIdContesto : null,
    );

    if (!successo) {
      onShowError?.call('Si è verificato un problema col recupero delle fonti');
      try {
        await _chatService.resetContextSession();
      } catch (e) {
        debugPrint('[CHAT] Errore reset contesto dopo fallimento: $e');
      }
    }

    notifyListeners();
    onScrollToBottom?.call();
  }

  Future<void> inviaMessaggio(String testo) async {
    if (testo.isEmpty || botStaScrivendo) return;

    botStaScrivendo = true;
    notifyListeners();

    _chatService.aggiungiMessaggio(
      MessaggioChat(testo: testo, isUtente: true, timestamp: DateTime.now()),
    );

    onScrollToBottom?.call();

    try {
      // collection_id della collezione dei libri in fonte bloccata (se c'e').
      // Si ricalcola a ogni domanda, perche' i libri della collezione possono
      // essere arrivati dal server dopo che il contesto e' stato creato.
      final collectionId = _collectionIdContesto;
      _chatService.impostaCollezioneContesto(collectionId);
      debugPrint(
        '[CHAT] collection_id della domanda: $collectionId '
        '(fonte bloccata: $isContextLocked, libri: $activeBookIds)',
      );

      final risposta = await _chatService.inviaMessaggio(
        testo,
        collectionId: collectionId,
      );
      _chatService.aggiungiMessaggio(risposta);
      _chatService.aggiornaFonti(risposta.fonti);
    } catch (e) {
      // il service ora lancia messaggi specifici per 403/409/410/413/
      // 422/503 (non iniziano con "Errore"): in quel caso li mostriamo, per
      // gli altri errori resta il messaggio di prima.
      final dettaglio = e.toString().replaceFirst('Exception: ', '');
      final isSpecifico = !dettaglio.startsWith('Errore');

      _chatService.aggiungiMessaggio(
        MessaggioChat(
          testo: isSpecifico
              ? dettaglio
              : 'Si è verificato un errore. '
                    'Verifica la tua connessione e riprova.',
          isUtente: false,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      botStaScrivendo = false;
      notifyListeners();
      onScrollToBottom?.call();
    }
  }
}