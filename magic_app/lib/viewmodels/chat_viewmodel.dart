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

    _chatService.aggiungiMessaggio(
      MessaggioChat(
        testo: 'Modalità Smart',
        isUtente: false,
        timestamp: DateTime.now(),
        isSystem: true,
      ),
    );

    _chatService.aggiungiMessaggio(
      MessaggioChat(
        testo: 'Nessun manoscritto selezionato.\nChat in modalità smart.',
        isUtente: false,
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
    onScrollToBottom?.call();
  }

  Future<void> _inizializzaContextSession(
    List<String> ids,
    String nomeContesto,
  ) async {
    contextSessionInCorso = true;
    notifyListeners();

    _chatService.aggiungiMessaggio(
      MessaggioChat(
        testo: nomeContesto,
        isUtente: false,
        timestamp: DateTime.now(),
        isSystem: true,
      ),
    );

    _chatService.aggiungiMessaggio(
      MessaggioChat(
        testo: 'Sto recuperando le fonti per "$nomeContesto"...',
        isUtente: false,
        timestamp: DateTime.now(),
      ),
    );

    onScrollToBottom?.call();

    final successo = await _chatService.creaContextSession(ids);

    contextSessionInCorso = false;
    notifyListeners();

    _chatService.aggiungiMessaggio(
      MessaggioChat(
        testo: successo
            ? 'Fonti recuperate con successo! Ora le mie risposte '
                  'saranno limitate a questa selezione.'
            : 'Si è verificato un problema col recupero delle fonti, '
                  'ma proverò comunque ad aiutarti.',
        isUtente: false,
        timestamp: DateTime.now(),
      ),
    );

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
              'Si è verificato un errore di comunicazione con il server. '
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
