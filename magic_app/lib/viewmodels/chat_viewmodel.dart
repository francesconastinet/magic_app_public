import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/chat_service.dart';

class ChatViewModel extends ChangeNotifier {
  // --- DIPENDENZE ---
  final ChatService _chatService;

  // --- STATO ---
  bool botStaScrivendo = false;
  bool contextSessionInCorso = false;
  Timer? _pollingTimer;

  // --- GETTER ---
  List<MessaggioChat> get messaggi => _chatService.messaggi;
  List<FonteChat> get fontiTotali => _chatService.fontiTotali;
  bool get contextSessionCreata => _chatService.contextSessionId != null;
  bool get isGuest => _chatService.isGuest;

  // --- EVENTI UI ---
  VoidCallback? onScrollToBottom;
  void Function(String)? onShowError;

  ChatViewModel({required this._chatService}) {
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
      _inizializzaContextSession(ids, titolo ?? 'Manoscritto');
    }
  }

  void aggiornaContesto(List<String>? nuoviIds, String? nuovoTitolo) {
    if (nuoviIds != null && nuoviIds.isNotEmpty) {
      _inizializzaContextSession(nuoviIds, nuovoTitolo ?? 'Manoscritto');
    } else {
      _impostaModalitaSmart();
    }
  }

  void _impostaModalitaSmart() {
    _chatService.resetContextSession();
    notifyListeners();
    onScrollToBottom?.call();
  }

  Future<void> _inizializzaContextSession(
    List<String> ids,
    String nomeContesto,
  ) async {
    contextSessionInCorso = true;
    notifyListeners();

    final successo = await _chatService.creaContextSession(ids);

    contextSessionInCorso = false;

    if (!successo) {
      onShowError?.call('Si è verificato un problema col recupero delle fonti');
    }

    notifyListeners();
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
      onShowError?.call(
        'Si è verificato un errore di comunicazione con '
        'il server. Verifica la tua connessione e riprova.',
      );
    } finally {
      botStaScrivendo = false;
      notifyListeners();
      onScrollToBottom?.call();
    }
  }
}
