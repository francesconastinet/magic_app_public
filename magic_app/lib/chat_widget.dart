import 'package:flutter/material.dart';
import 'chat_service.dart';

// ==========================================
// SCHERMATA WIDGET
// ==========================================

class ChatWidget extends StatefulWidget {
  final String? titoloFonteSelezionata;
  final List<String>? bookIds;

  const ChatWidget({super.key, this.titoloFonteSelezionata, this.bookIds});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final ChatService _chatService = ChatService();
  final List<MessaggioChat> _messaggi = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _botStaScrivendo = false;
  bool _contextSessionCreata = false;
  bool _contextSessionInCorso = false;
  final List<FonteChat> _fonteTotali = [];

  @override
  void initState() {
    super.initState();
    _aggiungiMessaggioBenvenuto();
    _gestisciInizializzazioneContesto(widget.bookIds);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ChatHeaderBar(
          titoloFonte: widget.titoloFonteSelezionata,
          inCorso: _contextSessionInCorso,
          creata: _contextSessionCreata,
          numeroFonti: _fonteTotali.length,
          onMostraFonti: () => _mostraListaFonti(context),
        ),

        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messaggi.length + (_botStaScrivendo ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messaggi.length && _botStaScrivendo) {
                return const ChatTypingIndicator();
              }
              return ChatMessageBubble(msg: _messaggi[index]);
            },
          ),
        ),

        ChatInputArea(
          controller: _controller,
          isWriting: _botStaScrivendo,
          onSend: _invia,
        ),
      ],
    );
  }

  // --- LOGICA ---
  @override
  void didUpdateWidget(covariant ChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookIds != oldWidget.bookIds) {
      if (widget.bookIds != null && widget.bookIds!.isNotEmpty) {
        _gestisciInizializzazioneContesto(widget.bookIds);
      } else {
        _chatService.resetContextSession();
      }
    }
  }

  void _gestisciInizializzazioneContesto(List<String>? ids) {
    if (ids != null && ids.isNotEmpty) {
      _inizializzaContextSession(ids, widget.titoloFonteSelezionata ?? 'Libro');
    }
  }

  Future<void> _inizializzaContextSession(
    List<String> ids,
    String nomeContesto,
  ) async {
    setState(() {
      _contextSessionInCorso = true;
      _messaggi.add(
        MessaggioChat(
          testo: 'Hai selezionato "$nomeContesto". Sto recuperando le fonti...',
          isUtente: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollaInFondo();

    final successo = await _chatService.creaContextSession(ids);

    if (!mounted) return;

    setState(() {
      _contextSessionCreata = successo;
      _contextSessionInCorso = false;
      _messaggi.add(
        MessaggioChat(
          testo: successo
              ? 'Fonti recuperate con successo! Ora risponderò '
                    'basandomi esclusivamente su "$nomeContesto".'
              : 'Si è verificato un problema col recupero delle fonti, '
                    'ma proverò comunque ad aiutarti.',
          isUtente: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollaInFondo();
  }

  void _aggiungiMessaggioBenvenuto() {
    setState(() {
      _messaggi.add(
        MessaggioChat(
          testo:
              'Ciao! Sono il tuo assistente virtuale per la '
              'Biblioteca dei Girolamini. Come posso aiutarti?',
          isUtente: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

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

  void _aggiornaFonti(List<FonteChat> nuoveFonti) {
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

    setState(() {
      _messaggi.add(
        MessaggioChat(testo: testo, isUtente: true, timestamp: DateTime.now()),
      );
      _botStaScrivendo = true;
      _controller.clear();
    });
    _scrollaInFondo();

    try {
      final risposta = await _chatService.inviaMessaggio(testo);
      if (!mounted) return;

      setState(() {
        _messaggi.add(risposta);
        _aggiornaFonti(risposta.fonti);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messaggi.add(
          MessaggioChat(
            testo:
                'Si è verificato un errore di comunicazione con il server. '
                'Verifica la tua connessione e riprova.',
            isUtente: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _botStaScrivendo = false);
        _scrollaInFondo();
      }
    }
  }

  void _mostraListaFonti(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FontiBottomSheet(fonteTotali: _fonteTotali),
    );
  }
}

// ==========================================
// WIDGET
// ==========================================

// --- BARRA SUPERIORE ---
class ChatHeaderBar extends StatelessWidget {
  final String? titoloFonte;
  final bool inCorso;
  final bool creata;
  final int numeroFonti;
  final VoidCallback onMostraFonti;

  const ChatHeaderBar({
    super.key,
    this.titoloFonte,
    required this.inCorso,
    required this.creata,
    required this.numeroFonti,
    required this.onMostraFonti,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: colorScheme.secondaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.folder_open,
            size: 14,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              titoloFonte != null ? 'Fonte: $titoloFonte' : 'Nessuna fonte',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (inCorso)
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
              creata ? Icons.check : Icons.close,
              size: 14,
              color: creata ? Colors.green : Colors.orange,
            ),
          const SizedBox(width: 12),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.menu_book,
                  size: 20,
                  color: colorScheme.onSecondaryContainer,
                ),
                if (numeroFonti > 0)
                  Positioned(
                    right: -4,
                    top: -4,
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
                        '$numeroFonti',
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
            onPressed: onMostraFonti,
          ),
        ],
      ),
    );
  }
}

// --- INPUT TESTUALE ---
class ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isWriting;
  final VoidCallback onSend;

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.isWriting,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colorScheme.surface),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
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
              onSubmitted: (_) => onSend(),
              enabled: !isWriting,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'chat_send',
            onPressed: isWriting ? null : onSend,
            backgroundColor: colorScheme.primary,
            child: Icon(Icons.send, color: colorScheme.onPrimary),
          ),
        ],
      ),
    );
  }
}

// --- CARICAMENTO MESSAGGIO ---
class ChatTypingIndicator extends StatelessWidget {
  const ChatTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CustomPaint(
            painter: ChatTailPainter(
              bgColor: colorScheme.surfaceContainerHighest,
              isUtente: false,
            ),
            size: const Size(6, 12),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(0),
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

// --- BOLLA MESSAGGIO ---
class ChatMessageBubble extends StatelessWidget {
  final MessaggioChat msg;

  const ChatMessageBubble({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUtente = msg.isUtente;
    final timeStr =
        '${msg.timestamp.hour.toString().padLeft(2, '0')}:'
        '${msg.timestamp.minute.toString().padLeft(2, '0')}';

    final bgColor = isUtente
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final textColor = isUtente ? colorScheme.onPrimary : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUtente
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUtente)
            CustomPaint(
              painter: ChatTailPainter(bgColor: bgColor, isUtente: false),
              size: const Size(6, 12),
            ),

          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.only(
                left: 14,
                right: 14,
                top: 10,
                bottom: 6,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUtente ? 16 : 0),
                  bottomRight: Radius.circular(isUtente ? 0 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.testo,
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),

                  if (!isUtente && msg.fonti.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Libri consultati:',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    ...msg.fonti.map(
                      (fonte) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '• ${fonte.title.isNotEmpty ? fonte.title : fonte.identifier}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        color: isUtente
                            ? colorScheme.onPrimary.withValues(alpha: 0.7)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isUtente)
            CustomPaint(
              painter: ChatTailPainter(bgColor: bgColor, isUtente: true),
              size: const Size(6, 12),
            ),
        ],
      ),
    );
  }
}

// --- PANNELLO FONTI CONSULTATE ---
class FontiBottomSheet extends StatelessWidget {
  final List<FonteChat> fonteTotali;

  const FontiBottomSheet({super.key, required this.fonteTotali});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Libri consultati',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Usati: ${fonteTotali.length}',
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
          Expanded(
            child: fonteTotali.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Fai una domanda per vedere\ni libri consultati.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: fonteTotali.length,
                    itemBuilder: (context, index) {
                      final fonte = fonteTotali[index];
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
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// --- PAINTER BUBBLE ---
class ChatTailPainter extends CustomPainter {
  final Color bgColor;
  final bool isUtente;

  ChatTailPainter({required this.bgColor, required this.isUtente});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = bgColor;
    final path = Path();

    if (isUtente) {
      path.moveTo(0, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
