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

    for (var coll in _catalogueRepo.collezioni) {
      if (coll.bookIds.length == ids.length &&
          coll.bookIds.every((id) => ids.contains(id))) {
        return coll.name;
      }
    }

    return 'Manoscritti vari';
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
    if (nuoviIds != null && nuoviIds.isNotEmpty) {
      await _inizializzaContextSession(nuoviIds);
    } else {
      await _impostaModalitaSmart();
    }
  }

  Future<void> _impostaModalitaSmart() async {
    contextSessionInCorso = true;
    notifyListeners();

    await _chatService.resetContextSession();

    contextSessionInCorso = false;
    notifyListeners();
    onScrollToBottom?.call();
  }

  Future<void> _inizializzaContextSession(List<String> ids) async {
    contextSessionInCorso = true;
    notifyListeners();

    bool successo = await _chatService.creaContextSession(ids);

    if (successo) {
      successo = await _chatService.impostaBloccoContesto(true);
    }

    contextSessionInCorso = false;

    if (!successo) {
      onShowError?.call('Si è verificato un problema col recupero delle fonti');
      await _chatService.resetContextSession();
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
      final risposta = await _chatService.inviaMessaggio(testo);
      _chatService.aggiungiMessaggio(risposta);
      _chatService.aggiornaFonti(risposta.fonti);
    } catch (e) {
      _chatService.aggiungiMessaggio(
        MessaggioChat(
          testo:
              'Si è verificato un errore. '
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
