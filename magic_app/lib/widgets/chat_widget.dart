import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';

// ==========================================
// SCHERMATA
// ==========================================

class ChatWidget extends StatefulWidget {
  final String? titoloFonteSelezionata;
  final List<String>? bookIds;

  const ChatWidget({super.key, this.titoloFonteSelezionata, this.bookIds});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _botStaScrivendo = false;
  bool _contextSessionCreata = false;
  bool _contextSessionInCorso = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _aggiungiMessaggioBenvenuto();
      _gestisciInizializzazioneContesto(widget.bookIds);
    });
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
    final chatService = context.watch<ChatService>();
    final messaggi = chatService.messaggi;
    final bool fontiBloccate = widget.bookIds != null && widget.bookIds!.isNotEmpty;

    return Column(
      children: [
        if (fontiBloccate)
          ChatHeaderBar(
            titoloFonte: widget.titoloFonteSelezionata,
            inCorso: _contextSessionInCorso,
            creata: _contextSessionCreata,
          ),

        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: messaggi.length + (_botStaScrivendo ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == messaggi.length && _botStaScrivendo) {
                return const ChatTypingIndicator();
              }

              final msg = messaggi[index];

              if (msg.isSystem) {
                return _buildSystemSeparator(
                  msg.testo,
                  Theme.of(context).colorScheme,
                );
              }

              return ChatMessageBubble(msg: msg);
            },
          ),
        ),

        ChatInputArea(
          controller: _controller,
          isWriting: _botStaScrivendo,
          onSend: _inviaMessaggio,
        ),
      ],
    );
  }

  // --- LOGICA ---
  @override
  void didUpdateWidget(covariant ChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.bookIds != oldWidget.bookIds) {
      final chatService = context.read<ChatService>();

      if (widget.bookIds != null && widget.bookIds!.isNotEmpty) {
        _gestisciInizializzazioneContesto(widget.bookIds);
      } else {
        chatService.resetContextSession();

        chatService.aggiungiMessaggio(
          MessaggioChat(
            testo: 'Fonti sbloccate',
            isUtente: false,
            timestamp: DateTime.now(),
            isSystem: true,
          ),
        );

        chatService.aggiungiMessaggio(
          MessaggioChat(
            testo:
                'Nessuna fonte selezionata.\n'
                'Chat in modalità fonti sbloccate.',
            isUtente: false,
            timestamp: DateTime.now(),
          ),
        );

        _scrollaInFondo();
      }
    }
  }

  void _gestisciInizializzazioneContesto(List<String>? ids) {
    if (ids != null && ids.isNotEmpty) {
      _inizializzaContextSession(
        ids,
        widget.titoloFonteSelezionata ?? 'Manoscritto',
      );
    }
  }

  Future<void> _inizializzaContextSession(
    List<String> ids,
    String nomeContesto,
  ) async {
    final chatService = context.read<ChatService>();

    setState(() {
      _contextSessionInCorso = true;
    });

    chatService.aggiungiMessaggio(
      MessaggioChat(
        testo: 'Nuova fonte: $nomeContesto',
        isUtente: false,
        timestamp: DateTime.now(),
        isSystem: true,
      ),
    );

    chatService.aggiungiMessaggio(
      MessaggioChat(
        testo: 'Sto recuperando le fonti...',
        isUtente: false,
        timestamp: DateTime.now(),
      ),
    );

    _scrollaInFondo();

    final successo = await chatService.creaContextSession(ids);

    if (!mounted) return;

    setState(() {
      _contextSessionCreata = successo;
      _contextSessionInCorso = false;
    });

    chatService.aggiungiMessaggio(
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

    _scrollaInFondo();
  }

  void _aggiungiMessaggioBenvenuto() {
    final chatService = context.read<ChatService>();
    if (chatService.messaggi.isEmpty) {
      chatService.aggiungiMessaggio(
        MessaggioChat(
          testo:
              'Ciao! Sono il tuo assistente virtuale per la '
              'Biblioteca dei Girolamini. Come posso aiutarti?',
          isUtente: false,
          timestamp: DateTime.now(),
        ),
      );
    }
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

  Future<void> _inviaMessaggio() async {
    final testo = _controller.text.trim();
    if (testo.isEmpty || _botStaScrivendo) return;

    final chatService = context.read<ChatService>();

    setState(() {
      _botStaScrivendo = true;
      _controller.clear();
    });

    chatService.aggiungiMessaggio(
      MessaggioChat(testo: testo, isUtente: true, timestamp: DateTime.now()),
    );

    _scrollaInFondo();

    try {
      final risposta = await chatService.inviaMessaggio(testo);
      if (!mounted) return;

      chatService.aggiungiMessaggio(risposta);
      chatService.aggiornaFonti(risposta.fonti);
    } catch (e) {
      if (!mounted) return;

      chatService.aggiungiMessaggio(
        MessaggioChat(
          testo:
              'Si è verificato un errore di comunicazione con il server. '
              'Verifica la tua connessione e riprova.',
          isUtente: false,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _botStaScrivendo = false);
        _scrollaInFondo();
      }
    }
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

  const ChatHeaderBar({
    super.key,
    this.titoloFonte,
    required this.inCorso,
    required this.creata,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: colorScheme.secondaryContainer,
      child: Row(
        children: [
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
              creata ? Icons.check_circle : Icons.cancel,
              size: 14,
              color: Colors.orange,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: IconButton.filledTonal(
              onPressed: () => context.push('/camera'),
              icon: const Icon(Icons.camera_alt),
              tooltip: 'Riconosci Manoscritto',
              style: IconButton.styleFrom(
                iconSize: 28,
                padding: const EdgeInsets.all(8),
              ),
            ),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
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
                tooltip: 'Invia',
                child: Icon(Icons.send, color: colorScheme.onPrimary),
              ),
            ],
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
                  width: 20,
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
    final isUtente = msg.isUtente;
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = isUtente ? colorScheme.onPrimary : colorScheme.onSurface;
    final timeStr =
        '${msg.timestamp.hour.toString().padLeft(2, '0')}:'
        '${msg.timestamp.minute.toString().padLeft(2, '0')}';
    final bgColor = isUtente
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;

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
                  'Manoscritti consultati',
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
                        'Fai una domanda per vedere i manoscritti consultati.',
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

// --- SEPARATORE MESSAGGI ---
Widget _buildSystemSeparator(String testo, ColorScheme colorScheme) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        Expanded(child: Divider(color: colorScheme.outlineVariant)),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              testo,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        Expanded(child: Divider(color: colorScheme.outlineVariant)),
      ],
    ),
  );
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
