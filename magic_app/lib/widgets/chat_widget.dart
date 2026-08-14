import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'catalogue_widget.dart';
import '../app_state.dart';
import '../services/chat_service.dart';

// ==========================================
// SCHERMATA
// ==========================================

class ChatWidget extends StatefulWidget {
  final String? titoloFonteSelezionata;
  final List<String>? bookIds;
  final void Function(String? titolo, List<String>? ids)? onFonteSelezionata;

  const ChatWidget({
    super.key,
    this.titoloFonteSelezionata,
    this.bookIds,
    this.onFonteSelezionata,
  });

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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        ChatHeaderBar(
          titoloFonte: widget.titoloFonteSelezionata,
          inCorso: _contextSessionInCorso,
          creata: _contextSessionCreata,
          onMostraFontiConsultate: () {
            showDialog(
              context: context,
              builder: (ctx) =>
                  FontiConsultateDialog(fonteTotali: chatService.fontiTotali),
            );
          },
        ),

        Expanded(
          child: Stack(
            children: [
              ListView.builder(
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

              Positioned(
                right: 12,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'fab_fonti',
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      elevation: 2,
                      tooltip: 'Gestisci Fonti',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (ctx) => CatalogueWidget(
                            idsFonteIniziale: widget.bookIds,
                            onFonteSelezionata:
                                widget.onFonteSelezionata ?? (t, ids) {},
                          ),
                        );
                      },
                      child: const Icon(Icons.library_books, size: 25),
                    ),

                    const SizedBox(height: 12),

                    FloatingActionButton.small(
                      heroTag: 'fab_ar',
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      elevation: 2,
                      tooltip: 'Realtà Aumentata',
                      onPressed: () {
                        final appState = context.read<AppState>();
                        if (appState.operaSelezionata != null) {
                          context.push(
                            '/ar/${appState.operaSelezionata!.titolo}',
                          );
                        } else {
                          context.push('/ar');
                        }
                      },
                      child: const Icon(Icons.camera_alt, size: 25),
                    ),
                  ],
                ),
              ),
            ],
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

    final bool idsCambiati = _listaStringheDiversa(
      widget.bookIds,
      oldWidget.bookIds,
    );
    final bool titoloCambiato =
        widget.titoloFonteSelezionata != oldWidget.titoloFonteSelezionata;

    if (idsCambiati || titoloCambiato) {
      final chatService = context.read<ChatService>();

      if (widget.bookIds != null && widget.bookIds!.isNotEmpty) {
        _inizializzaContextSession(
          widget.bookIds!,
          widget.titoloFonteSelezionata ?? 'Manoscritto',
        );
      } else {
        chatService.resetContextSession();

        chatService.aggiungiMessaggio(
          MessaggioChat(
            testo: 'Modalità Smart',
            isUtente: false,
            timestamp: DateTime.now(),
            isSystem: true,
          ),
        );

        chatService.aggiungiMessaggio(
          MessaggioChat(
            testo:
                'Nessun manoscritto selezionato.\n'
                'Chat in modalità smart.',
            isUtente: false,
            timestamp: DateTime.now(),
          ),
        );

        _scrollaInFondo();
      }
    }
  }

  bool _listaStringheDiversa(List<String>? list1, List<String>? list2) {
    if (list1 == null && list2 == null) return false;
    if (list1 == null || list2 == null) return true;
    if (list1.length != list2.length) return true;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return true;
    }
    return false;
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

    if (!mounted) return;

    setState(() {
      _contextSessionInCorso = true;
    });

    chatService.aggiungiMessaggio(
      MessaggioChat(
        testo: nomeContesto,
        isUtente: false,
        timestamp: DateTime.now(),
        isSystem: true,
      ),
    );

    chatService.aggiungiMessaggio(
      MessaggioChat(
        testo: 'Sto recuperando le fonti per "$nomeContesto"...',
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
  final VoidCallback onMostraFontiConsultate;

  const ChatHeaderBar({
    super.key,
    this.titoloFonte,
    required this.inCorso,
    required this.creata,
    required this.onMostraFontiConsultate,
  });

  void _mostraInfoDialog(
    BuildContext context,
    bool isSmartMode,
    String titolo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => InfoStatoDialog(
        isSmartMode: isSmartMode,
        titoloFonte: titolo,
        inCorso: inCorso,
        creata: creata,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmartMode =
        titoloFonte == null || titoloFonte!.isEmpty || titoloFonte == 'Misti';
    final testoVisualizzato = isSmartMode ? 'Modalità Smart' : '$titoloFonte';

    return Container(
      width: double.infinity,
      height: 32,
      color: colorScheme.secondaryContainer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  _mostraInfoDialog(context, isSmartMode, testoVisualizzato),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 4.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (inCorso)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      )
                    else
                      Icon(
                        creata
                            ? Icons.check_circle
                            : (isSmartMode
                                  ? Icons.auto_awesome
                                  : Icons.error_outline),
                        size: 16,
                        color: isSmartMode
                            ? Colors.orange
                            : (creata ? Colors.green : colorScheme.error),
                      ),

                    const SizedBox(width: 6),

                    Flexible(
                      child: Text(
                        testoVisualizzato,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(width: 4),

                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: colorScheme.onSecondaryContainer.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (isSmartMode)
            Positioned(
              right: 12,
              child: SizedBox(
                width: 24,
                height: 24,
                child: IconButton.filledTonal(
                  onPressed: onMostraFontiConsultate,
                  icon: const Icon(Icons.saved_search, size: 20),
                  tooltip: 'Fonti Consultate',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- PANNELLO FONTI CONSULTATE SMART ---
class FontiConsultateDialog extends StatelessWidget {
  final List<FonteChat> fonteTotali;

  const FontiConsultateDialog({super.key, required this.fonteTotali});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      title: Container(
        padding: const EdgeInsets.all(16),
        color: colorScheme.primaryContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Manoscritti consultati',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            Text(
              'Usati: ${fonteTotali.length}',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
    );
  }
}

// --- INFORMAZIONI STATO CHAT ---
class InfoStatoDialog extends StatelessWidget {
  final bool isSmartMode;
  final String titoloFonte;
  final bool inCorso;
  final bool creata;

  const InfoStatoDialog({
    super.key,
    required this.isSmartMode,
    required this.titoloFonte,
    required this.inCorso,
    required this.creata,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String statoTitolo;
    String statoDescrizione;
    IconData statoIcona;
    Color statoColore;

    if (inCorso) {
      statoTitolo = 'Caricamento in corso...';
      statoDescrizione =
          'Sto recuperando e indicizzando le fonti richieste. '
          'Potrebbe volerci qualche istante.';
      statoIcona = Icons.sync;
      statoColore = colorScheme.primary;
    } else if (isSmartMode) {
      statoTitolo = 'Modalità Smart Attiva';
      statoDescrizione =
          'Non hai selezionato nessun manoscritto. '
          'L\'intelligenza artificiale sceglierà automaticamente '
          'le fonti più pertinenti dall\'intero catalogo '
          'per rispondere alle tue domande.';
      statoIcona = Icons.auto_awesome;
      statoColore = Colors.orange;
    } else if (creata) {
      statoTitolo = 'Fonti Caricate';
      statoDescrizione =
          'La chat è stata limitata ai manoscritti selezionati. '
          'Tutte le risposte si baseranno solo su questi testi.';
      statoIcona = Icons.check_circle;
      statoColore = Colors.green;
    } else {
      statoTitolo = 'Errore di Caricamento';
      statoDescrizione =
          'Si è verificato un problema nel caricamento '
          'delle fonti selezionate. '
          'L\'assistente proverà comunque a rispondere.';
      statoIcona = Icons.error_outline;
      statoColore = colorScheme.error;
    }

    return AlertDialog(
      titlePadding: const EdgeInsets.all(20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.onSurface),
          const SizedBox(width: 12),
          const Text('Stato della Chat', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MANOSCRITTI SELEZIONATI:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            isSmartMode ? 'Nessuno' : titoloFonte,
            style: const TextStyle(fontSize: 14),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(height: 1),
          ),

          Text(
            'STATO CONNESSIONE:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(statoIcona, color: statoColore, size: 28),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statoTitolo,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statoColore,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      statoDescrizione,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi'),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: colorScheme.surface),
      child: Row(
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
            elevation: 0,
            onPressed: isWriting ? null : onSend,
            backgroundColor: colorScheme.primary,
            tooltip: 'Invia',
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
