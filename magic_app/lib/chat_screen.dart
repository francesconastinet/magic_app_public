import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'chat_service.dart';
import 'models.dart';

class ChatScreen extends StatefulWidget {
  final BookModel book;

  const ChatScreen({
    super.key,
    required this.book,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final List<MessaggioChat> _messaggi = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _botStaScrivendo = false;

  @override
  void initState() {
    super.initState();
    // Messaggio di benvenuto contestuale al libro 
    _aggiungiMessaggioBenvenuto();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Aggiunge messaggio di benvenuto con contesto del libro
  void _aggiungiMessaggioBenvenuto() {
    setState(() {
      _messaggi.add(MessaggioChat(
        testo: 'Ciao! Sono il tuo assistente virtuale per '
            '"${widget.book.titolo}" di ${widget.book.autore}. '
            'Puoi farmi domande su questo libro o sulla collezione '
            'dei Girolamini. Come posso aiutarti?',
        isUtente: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  // Scrolla verso il basso dopo il ridisegno del frame
  void _scrollaInFondo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _invia() async {
    final testo = _controller.text.trim();
    if (testo.isEmpty || _botStaScrivendo) return;

    // Aggiunge messaggio utente
    setState(() {
      _messaggi.add(MessaggioChat(
        testo: testo,
        isUtente: true,
        timestamp: DateTime.now(),
      ));
      _botStaScrivendo = true;
      _controller.clear();
    });
    _scrollaInFondo();

    try {
      // Invia al server e riceve risposta
      final risposta = await _chatService.inviaMessaggio(testo);
      setState(() {
        _messaggi.add(risposta);
        _botStaScrivendo = false;
      });
    } on DioException catch (e) {
      // Errore di connessione — distingue tra rete e server
      final messaggioErrore = e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError
          ? 'Errore di connessione — verifica la rete e riprova'
          : 'Errore del server — riprova tra qualche istante';

      setState(() {
        _messaggi.add(MessaggioChat(
          testo: messaggioErrore,
          isUtente: false,
          timestamp: DateTime.now(),
        ));
        _botStaScrivendo = false;
      });
    } catch (e) {
      setState(() {
        _messaggi.add(MessaggioChat(
          testo: 'Errore imprevisto — riprova',
          isUtente: false,
          timestamp: DateTime.now(),
        ));
        _botStaScrivendo = false;
      });
    }
    _scrollaInFondo();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assistente Virtuale',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.book.titolo,
                style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Lista messaggi
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount:
                  _messaggi.length + (_botStaScrivendo ? 1 : 0),
              itemBuilder: (context, index) {
                // Bubble "Bot sta scrivendo..."
                if (index == _messaggi.length && _botStaScrivendo) {
                  return _buildBubbleScrittura(colorScheme);
                }
                return _buildBubble(_messaggi[index], colorScheme);
              },
            ),
          ),

          // Input testo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Fai una domanda...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _invia(),
                    enabled: !_botStaScrivendo,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: _botStaScrivendo ? null : _invia,
                  backgroundColor: colorScheme.primary,
                  child: Icon(
                    Icons.send,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bubble singolo messaggio
  Widget _buildBubble(MessaggioChat msg, ColorScheme colorScheme) {
    final isUtente = msg.isUtente;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUtente ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Etichetta mittente
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: Text(
              isUtente ? 'Tu' : 'V.A.',
              style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold),
            ),
          ),
          // Bubble testo
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUtente
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUtente ? 16 : 4),
                bottomRight: Radius.circular(isUtente ? 4 : 16),
              ),
            ),
            child: Text(
              msg.testo,
              style: TextStyle(
                color: isUtente
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
              ),
            ),
          ),
          // Fonti libri consultati (solo per messaggi bot)
          if (!isUtente && msg.fonti.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Libri consultati:',
                style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic),
              ),
            ),
            ...msg.fonti.map((fonte) => Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Text(
                    '• ${fonte.title.isNotEmpty ? fonte.title : fonte.identifier}',
                    style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.primary),
                  ),
                )),
          ],
          // Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              '${msg.timestamp.hour.toString().padLeft(2, '0')}:'
              '${msg.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                  fontSize: 10, color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  // Bubble animata "Bot sta scrivendo..."
  Widget _buildBubbleScrittura(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4),
            child: Text('V.A.',
                style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Sto elaborando...',
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}