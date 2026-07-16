import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'chat_service.dart';
import 'models.dart';

class ChatScreen extends StatefulWidget {
  final BookModel book;

  const ChatScreen({super.key, required this.book});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final List<MessaggioChat> _messaggi = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _botStaScrivendo = false;

  // Lista fonti accumulate durante la conversazione
  final List<FonteChat> _fonteTotali = [];

  // Stato context session per modalita' fonti bloccate
  bool _contextSessionCreata = false;
  bool _contextSessionInCorso = false;

  @override
  void initState() {
    super.initState();
    // Messaggio di benvenuto contestuale al libro
    _aggiungiMessaggioBenvenuto();
    // Crea context session vincolata al libro corrente
    _inizializzaContextSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Crea context session vincolata all'id del libro corrente
  Future<void> _inizializzaContextSession() async {
    setState(() => _contextSessionInCorso = true);
    final successo = await _chatService.creaContextSession([widget.book.id]);
    setState(() {
      _contextSessionCreata = successo;
      _contextSessionInCorso = false;
    });
    debugPrint('[CHAT] Context session inizializzata: $_contextSessionCreata');
  }

  // Aggiunge messaggio di benvenuto con contesto del libro
  void _aggiungiMessaggioBenvenuto() {
    setState(() {
      _messaggi.add(
        MessaggioChat(
          testo:
              'Ciao! Sono il tuo assistente virtuale per '
              '"${widget.book.titolo}" di ${widget.book.autore}. '
              'Puoi farmi domande su questo libro o sulla collezione '
              'dei Girolamini. Come posso aiutarti?',
          isUtente: false,
          timestamp: DateTime.now(),
        ),
      );
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

  // Aggiunge le nuove fonti alla lista totale evitando duplicati
  void _aggiorneFonti(List<FonteChat> nuoveFonti) {
    for (final fonte in nuoveFonti) {
      final giaPresente = _fonteTotali.any(
        (f) => f.workId == fonte.workId && fonte.workId.isNotEmpty,
      );
      if (!giaPresente) {
        _fonteTotali.add(fonte);
      }
    }
  }

  Future<void> _invia() async {
    final testo = _controller.text.trim();
    if (testo.isEmpty || _botStaScrivendo) return;

    // Aggiunge messaggio utente
    setState(() {
      _messaggi.add(
        MessaggioChat(testo: testo, isUtente: true, timestamp: DateTime.now()),
      );
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
        // Aggiorna le fonti totali con quelle della nuova risposta
        _aggiorneFonti(risposta.fonti);
      });
    } on DioException catch (e) {
      // Errore di connessione — distingue tra rete e server
      final messaggioErrore =
          e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError
          ? 'Errore di connessione — verifica la rete e riprova'
          : 'Errore del server — riprova tra qualche istante';

      setState(() {
        _messaggi.add(
          MessaggioChat(
            testo: messaggioErrore,
            isUtente: false,
            timestamp: DateTime.now(),
          ),
        );
        _botStaScrivendo = false;
      });
    } catch (e) {
      setState(() {
        _messaggi.add(
          MessaggioChat(
            testo: 'Errore imprevisto — riprova',
            isUtente: false,
            timestamp: DateTime.now(),
          ),
        );
        _botStaScrivendo = false;
      });
    }
    _scrollaInFondo();
  }

  // Drawer con lista fonti accumulate durante la conversazione
  Widget _buildDrawerFonti(ColorScheme colorScheme) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header drawer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: colorScheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fonti consultate',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_fonteTotali.length} libro/i usato/i',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Lista fonti
            Expanded(
              child: _fonteTotali.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Nessuna fonte ancora.\nFai una domanda per vedere\ni libri consultati.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _fonteTotali.length,
                      itemBuilder: (context, index) {
                        final fonte = _fonteTotali[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fonte.title.isNotEmpty
                                      ? fonte.title
                                      : fonte.identifier,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (fonte.author.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    fonte.author,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                if (fonte.date.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    fonte.date,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                if (fonte.rilevanza != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.analytics_outlined,
                                        size: 12,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Rilevanza: ${(fonte.rilevanza! * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.format_quote,
                                        size: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${fonte.chunksCount} estratti',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Drawer fonti sul lato destro
      endDrawer: _buildDrawerFonti(colorScheme),
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assistente Virtuale',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(widget.book.titolo, style: const TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          // Bottone per aprire il drawer fonti
          Builder(
            builder: (ctx) => IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.menu_book),
                  if (_fonteTotali.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '${_fonteTotali.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Fonti consultate',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tag visibile modalita' fonti bloccate sul libro corrente
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: colorScheme.secondaryContainer,
            child: Row(
              children: [
                Icon(
                  Icons.book_outlined,
                  size: 14,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Libro: ${widget.book.titolo}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                // Indicatore stato context session
                if (_contextSessionInCorso)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  )
                else
                  Icon(
                    _contextSessionCreata
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                    size: 14,
                    color: _contextSessionCreata ? Colors.green : Colors.orange,
                  ),
              ],
            ),
          ),

          // Lista messaggi
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messaggi.length + (_botStaScrivendo ? 1 : 0),
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
                ),
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
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _invia(),
                    enabled: !_botStaScrivendo,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'chat_send',
                  onPressed: _botStaScrivendo ? null : _invia,
                  backgroundColor: colorScheme.primary,
                  child: Icon(Icons.send, color: colorScheme.onPrimary),
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
        crossAxisAlignment: isUtente
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Etichetta mittente
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: Text(
              isUtente ? 'Tu' : 'V.A.',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Bubble testo
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                color: isUtente ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
          ),
          // Fonti libri consultati sotto la bubble bot — solo se presenti
          if (!isUtente && msg.fonti.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Libri consultati:',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            ...msg.fonti.map(
              (fonte) => Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text(
                  '• ${fonte.title.isNotEmpty ? fonte.title : fonte.identifier}',
                  style: TextStyle(fontSize: 11, color: colorScheme.primary),
                ),
              ),
            ),
          ],
          // Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              '${msg.timestamp.hour.toString().padLeft(2, '0')}:'
              '${msg.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
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
            child: Text(
              'V.A.',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                Text(
                  'Sto elaborando...',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
