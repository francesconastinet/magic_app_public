import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'media_service.dart';
import 'models.dart';
import 'chat_widget.dart';
import 'widgets/audio_widget.dart';
import 'widgets/image_dialog.dart';
import 'widgets/pdf_dialog.dart';
import 'widgets/text_dialog.dart';
import 'widgets/video_dialog.dart';

// ==========================================
// CONFIGURAZIONE LAYOUT
// ==========================================

class ARLayout {
  final Size screenSize;
  final EdgeInsets safePadding;
  final bool isLandscape;
  final bool isTablet;

  ARLayout(BuildContext context)
    : screenSize = MediaQuery.sizeOf(context),
      safePadding = MediaQuery.paddingOf(context),
      isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape,
      isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

  // --- MIRINO FOTOCAMERA ---
  double get viewfinderWidth => (screenSize.width * 0.6).clamp(150.0, 300.0);
  double get viewfinderHeight => (screenSize.height * 0.4).clamp(200.0, 400.0);

  // --- PANNELLO INFO OPERA ---
  Alignment get infoAlignment {
    if (isLandscape) {
      return isTablet ? Alignment.topRight : Alignment.topLeft;
    }
    return Alignment.topCenter;
  }

  double get infoMaxWidth {
    if (isLandscape) {
      return (screenSize.width * (isTablet ? 0.3 : 0.2)).clamp(220.0, 450.0);
    } else {
      return (screenSize.width * (isTablet ? 0.75 : 0.9)).clamp(300.0, 600.0);
    }
  }

  double get infoTop => safePadding.top;
  double get infoLeft => safePadding.left + 16.0;
  double get infoRight => safePadding.right + 16.0;
  double get infoTitleFontSize => isTablet ? 20.0 : 16.0;
  double get infoTextFontSize => isTablet ? 14.0 : 13.0;
  double get infoIconSize => isTablet ? 26.0 : 20.0;
  double get infoPadding => isTablet ? 14.0 : 12.0;

  // --- PANNELLO BOLLE MULTIMEDIALI ---
  double get bubblesTop {
    if (isLandscape) {
      return safePadding.top + (isTablet ? 170.0 : 16.0);
    }
    return safePadding.top + (isTablet ? 160.0 : 140.0);
  }

  double get bubblesPanelWidth =>
      isLandscape ? (isTablet ? 170.0 : 130.0) : (isTablet ? 85.0 : 60.0);
  double get bubblesBottom => safePadding.bottom + (isTablet ? 120.0 : 100.0);
  double get bubblesRight => safePadding.right + (isTablet ? 0.0 : 16.0);
  double get bubblesSize => isTablet ? 60.0 : 56.0;
  double get bubblesIconSize => isTablet ? 32.0 : 24.0;

  // --- BOTTONE CHAT ---
  double get chatBottom => safePadding.bottom;
  double get chatRight => safePadding.right + (isTablet ? 12.0 : 16.0);
  double get chatSize => isTablet ? 60.0 : 56.0;
  double get chatIconSize => isTablet ? 32.0 : 24.0;

  // --- BOTTONE CHIUDI ---
  double get closeBottom => safePadding.bottom;
  double get closeLeft => 0.0;
  double get closeRight => 0.0;
  double get closeSize => isTablet ? 60.0 : 56.0;
  double get closeIconSize => isTablet ? 32.0 : 24.0;

  // --- MENU DEBUG ---
  double get debugTop => safePadding.top + 160.0;
  double get debugLeft => 120.0;
  double get debugWidth => (screenSize.width * 0.5).clamp(180.0, 300.0);
}

// ==========================================
// SCHERMATA PRINCIPALE
// ==========================================

class ARScreen extends StatefulWidget {
  final String nomeOpera;
  const ARScreen({super.key, required this.nomeOpera});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> with TickerProviderStateMixin {
  bool _overlayVisibile = false;
  CameraController? _camController;
  bool _cameraReady = false;
  MediaItem? _audioInEsecuzione;
  bool _audioMinimizzato = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scanAnimation = CurvedAnimation(
      parent: _scanController,
      curve: Curves.easeInOut,
    );
    _scanController.repeat(reverse: true);

    _inizializzaCamera();
  }

  @override
  void dispose() {
    _camController?.dispose();
    _fadeController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final opera = context.watch<AppState>().operaSelezionata;

    return Scaffold(
      appBar: AppBar(title: const Text('Realtà Aumentata')),
      body: _buildBody(opera),
    );
  }

  Widget _buildBody(BookModel? opera) {
    if (!_cameraReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final layout = ARLayout(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        ARCameraFeed(controller: _camController!, layout: layout),

        if (!_overlayVisibile)
          ARCameraViewfinder(scanAnimation: _scanAnimation, layout: layout),

        if (kDebugMode)
          ARDebugMenu(
            layout: layout,
            onSimulate: () {
              setState(() {
                _audioInEsecuzione = null;
              });
              _mostraOverlay();
            },
          ),

        if (_overlayVisibile && opera != null) ...[
          AROperaInfoPanel(
            opera: opera,
            fadeAnimation: _fadeAnimation,
            layout: layout,
          ),

          ARChatButton(
            opera: opera,
            overlayVisibile: _overlayVisibile,
            fadeAnimation: _fadeAnimation,
            layout: layout,
          ),

          ARCloseButton(
            overlayVisibile: _overlayVisibile,
            fadeAnimation: _fadeAnimation,
            layout: layout,
            onClose: _nascondiOverlay,
          ),

          ARMediaBubblesPanel(
            opera: opera,
            fadeAnimation: _fadeAnimation,
            layout: layout,
            audioInEsecuzione: _audioInEsecuzione,
            onPlayAudio: (item) {
              setState(() {
                _audioInEsecuzione = item;
                _audioMinimizzato = false;
              });
            },
            onReopenAudio: () {
              setState(() {
                _audioMinimizzato = false;
              });
            },
          ),

          if (_audioInEsecuzione != null)
            AudioWidget(
              titolo: _audioInEsecuzione!.titolo,
              audioPath: _audioInEsecuzione!.url,
              isMinimized: _audioMinimizzato,
              onMinimizeToggle: () {
                setState(() {
                  _audioMinimizzato = true;
                });
              },
              onClose: () {
                setState(() {
                  _audioInEsecuzione = null;
                });
              },
            ),
        ],
      ],
    );
  }

  // --- LOGICA ---
  Future<void> _inizializzaCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _camController = CameraController(cameras.first, ResolutionPreset.medium);
    await _camController!.initialize();

    if (mounted) {
      setState(() => _cameraReady = true);
      // TODO: colleagre al modello ML
      if (!_overlayVisibile) _mostraOverlay();
    }
  }

  void _mostraOverlay() {
    setState(() => _overlayVisibile = true);
    _scanController.stop();
    _fadeController.forward();
  }

  void _nascondiOverlay() {
    _fadeController.reverse().then((_) {
      if (mounted) {
        setState(() => _overlayVisibile = false);
        setState(() => _audioInEsecuzione = null);
        _scanController.repeat(reverse: true);
      }
    });
  }
}

// ==========================================
// WIDGET
// ==========================================

// --- FLUSSO VIDEO FOTOCAMERA ---
class ARCameraFeed extends StatelessWidget {
  final CameraController controller;
  final ARLayout layout;

  const ARCameraFeed({
    super.key,
    required this.controller,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    final fallbackWidth = layout.screenSize.width;
    final fallbackHeight = layout.screenSize.height;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize?.height ?? fallbackWidth,
          height: previewSize?.width ?? fallbackHeight,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

// --- MIRINO FOTOCAMERA ---
class ARCameraViewfinder extends StatelessWidget {
  final Animation<double> scanAnimation;
  final ARLayout layout;

  const ARCameraViewfinder({
    super.key,
    required this.scanAnimation,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: scanAnimation,
        builder: (context, child) {
          return Container(
            width: layout.viewfinderWidth,
            height: layout.viewfinderHeight,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: 0.4 + scanAnimation.value * 0.6,
                ),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Opacity(
                opacity: 0.4 + scanAnimation.value * 0.6,
                child: const Text(
                  'Punta sulla copertina',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- PANNELLO INFO OPERA ---
class AROperaInfoPanel extends StatelessWidget {
  final BookModel opera;
  final Animation<double> fadeAnimation;
  final ARLayout layout;

  const AROperaInfoPanel({
    super.key,
    required this.opera,
    required this.fadeAnimation,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: layout.infoTop,
      left: layout.infoLeft,
      right: layout.infoRight,
      child: Align(
        alignment: layout.infoAlignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.infoMaxWidth),
          child: _buildPanel(),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(layout.infoPadding),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 2.0, right: 8.0),
                  child: Icon(
                    Icons.menu_book,
                    color: Colors.blueAccent,
                    size: layout.infoIconSize,
                  ),
                ),
                Expanded(
                  child: Text(
                    opera.titolo,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: layout.infoTitleFontSize,
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6.0),
              child: Divider(color: Colors.white24, height: 1),
            ),
            Text(
              'Autore: ${opera.autore}',
              style: TextStyle(
                color: Colors.white70,
                fontSize: layout.infoTextFontSize,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'Anno: ${opera.anno}',
              style: TextStyle(
                color: Colors.white70,
                fontSize: layout.infoTextFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PANNELLO BOLLE MULTIMEDIALI ---
class ARMediaBubblesPanel extends StatelessWidget {
  final BookModel opera;
  final Animation<double> fadeAnimation;
  final ARLayout layout;
  final MediaItem? audioInEsecuzione;
  final void Function(MediaItem) onPlayAudio;
  final VoidCallback onReopenAudio;

  const ARMediaBubblesPanel({
    super.key,
    required this.opera,
    required this.fadeAnimation,
    required this.layout,
    required this.audioInEsecuzione,
    required this.onPlayAudio,
    required this.onReopenAudio,
  });

  @override
  Widget build(BuildContext context) {
    final fileMultimediali = opera.multimedia;
    if (fileMultimediali.isEmpty) return const SizedBox.shrink();

    final videoList = fileMultimediali.where((m) => m.tipo == 'video').toList();
    final audioList = fileMultimediali.where((m) => m.tipo == 'audio').toList();
    final immaginiList = fileMultimediali
        .where((m) => m.tipo == 'immagine')
        .toList();
    final pdfList = fileMultimediali.where((m) => m.tipo == 'pdf').toList();
    final testoList = fileMultimediali.where((m) => m.tipo == 'testo').toList();
    final linkList = fileMultimediali
        .where((m) => m.tipo == 'link_esterno')
        .toList();

    return Positioned(
      right: layout.bubblesRight,
      top: layout.bubblesTop,
      bottom: layout.bubblesBottom,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: SizedBox(
            width: layout.bubblesPanelWidth,
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 12,
              children: [
                if (videoList.isNotEmpty)
                  _buildBubble(context, Icons.videocam, 'Video', videoList),
                if (audioList.isNotEmpty)
                  _buildBubble(context, Icons.audiotrack, 'Audio', audioList),
                if (immaginiList.isNotEmpty)
                  _buildBubble(context, Icons.image, 'Immagini', immaginiList),
                if (pdfList.isNotEmpty)
                  _buildBubble(context, Icons.picture_as_pdf, 'PDF', pdfList),
                if (testoList.isNotEmpty)
                  _buildBubble(context, Icons.article, 'Testo', testoList),
                if (linkList.isNotEmpty)
                  _buildBubble(context, Icons.link, 'Link', linkList),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context,
    IconData icona,
    String tipo,
    List<MediaItem> mediaList,
  ) {
    if (mediaList.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: layout.bubblesSize,
      height: layout.bubblesSize,
      child: FloatingActionButton(
        heroTag: 'bubble_$tipo',
        backgroundColor: Colors.black.withValues(alpha: 0.75),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
        onPressed: () {
          if (tipo == 'Audio' && audioInEsecuzione != null) {
            onReopenAudio();
          } else {
            _mostraListaMedia(context, tipo, mediaList);
          }
        },
        child: Icon(icona, size: layout.bubblesIconSize),
      ),
    );
  }

  void _mostraListaMedia(
    BuildContext context,
    String titoloTipo,
    List<MediaItem> mediaList,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      'Contenuti: $titoloTipo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${mediaList.length} elementi',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: mediaList.length,
                  itemBuilder: (ctx, index) {
                    final item = mediaList[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.arrow_right,
                        color: Colors.white70,
                      ),
                      title: Text(
                        item.titolo,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (item.tipo == 'audio') {
                          onPlayAudio(item);
                          return;
                        }
                        if (item.tipo == 'link_esterno') {
                          context.read<MediaService>().apriUrl(item.url);
                          return;
                        }
                        if (item.tipo == 'pdf') {
                          showDialog(
                            context: context,
                            useSafeArea: false,
                            builder: (_) => PdfDialog(
                              titolo: item.titolo,
                              pdfPath: item.url,
                            ),
                          );
                          return;
                        }
                        showDialog(
                          context: context,
                          builder: (_) {
                            switch (item.tipo) {
                              case 'testo':
                                return TextDialog(
                                  titolo: item.titolo,
                                  textPath: item.url,
                                );
                              case 'immagine':
                                return ImageDialog(
                                  immagini: mediaList,
                                  initialIndex: index,
                                );
                              case 'video':
                                return VideoDialog(
                                  titolo: item.titolo,
                                  videoPath: item.url,
                                );
                              default:
                                return const AlertDialog(
                                  title: Text('Formato non supportato'),
                                );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- PULSANTE CHAT ---
class ARChatButton extends StatelessWidget {
  final BookModel opera;
  final bool overlayVisibile;
  final Animation<double> fadeAnimation;
  final ARLayout layout;

  const ARChatButton({
    super.key,
    required this.opera,
    required this.overlayVisibile,
    required this.fadeAnimation,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: layout.chatBottom,
      right: layout.chatRight,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: IgnorePointer(
          ignoring: !overlayVisibile,
          child: SizedBox(
            width: layout.chatSize,
            height: layout.chatSize,
            child: FloatingActionButton(
              heroTag: 'btn_chat',
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text('Chat')),
                      body: ChatWidget(
                        titoloFonteSelezionata: opera.titolo,
                        bookIds: [opera.id],
                      ),
                    ),
                  ),
                );
              },
              child: Icon(Icons.chat_bubble, size: layout.chatIconSize),
            ),
          ),
        ),
      ),
    );
  }
}

// --- PULSANTE CHIUDI ---
class ARCloseButton extends StatelessWidget {
  final bool overlayVisibile;
  final Animation<double> fadeAnimation;
  final ARLayout layout;
  final VoidCallback onClose;

  const ARCloseButton({
    super.key,
    required this.overlayVisibile,
    required this.fadeAnimation,
    required this.layout,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: layout.closeBottom,
      left: layout.closeLeft,
      right: layout.closeRight,
      child: Center(
        child: FadeTransition(
          opacity: fadeAnimation,
          child: IgnorePointer(
            ignoring: !overlayVisibile,
            child: SizedBox(
              width: layout.closeSize,
              height: layout.closeSize,
              child: FloatingActionButton(
                heroTag: 'btn_chiudi',
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.white24, width: 1),
                ),
                onPressed: onClose,
                child: Icon(Icons.close, size: layout.closeIconSize),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- MENU DEBUG ---
class ARDebugMenu extends StatelessWidget {
  final VoidCallback onSimulate;
  final ARLayout layout;

  const ARDebugMenu({
    super.key,
    required this.onSimulate,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: layout.debugTop,
      left: layout.debugLeft,
      width: layout.debugWidth,
      child: Card(
        color: Colors.black87,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MENU DEBUG',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 10),
              _buildButton(
                context: context,
                color: Colors.cyan.shade800,
                label: 'Divina Commedia',
                book: BookModel(
                  id: 'xyz',
                  titolo: 'Divina Commedia',
                  autore: 'Dante Alighieri',
                  anno: '1321',
                  multimedia: [
                    MediaItem(
                      tipo: 'video',
                      titolo: 'Spiegazione in 2 minuti',
                      url: 'assets/media/video_01.mp4',
                      descrizione: '',
                    ),
                    MediaItem(
                      tipo: 'audio',
                      titolo: 'Lettura Canto I',
                      url: 'assets/media/audio_01.mp3',
                      descrizione: '',
                    ),
                    MediaItem(
                      tipo: 'testo',
                      titolo: 'Riassunto trama',
                      url: 'assets/media/testo_01.txt',
                      descrizione: '',
                    ),
                    MediaItem(
                      tipo: 'immagine',
                      titolo: 'Copertina del libro',
                      url: 'assets/media/immagine_01.png',
                      descrizione: '',
                    ),
                    MediaItem(
                      tipo: 'immagine',
                      titolo: 'Struttura Inferno',
                      url: 'assets/media/immagine_02.png',
                      descrizione: '',
                    ),
                    MediaItem(
                      tipo: 'pdf',
                      titolo: 'Pdf Canto I',
                      url: 'assets/media/pdf_01.pdf',
                      descrizione: '',
                    ),
                    MediaItem(
                      tipo: 'link_esterno',
                      titolo: 'Parafrasi Divina Commedia',
                      url: 'https://divinacommedia.weebly.com/',
                      descrizione: '',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildButton(
                context: context,
                color: Colors.lime.shade800,
                label: 'Promessi Sposi',
                book: BookModel(
                  id: 'abc',
                  titolo: 'Promessi Sposi',
                  autore: 'Alessandro Manzoni',
                  anno: '1827',
                  multimedia: [
                    MediaItem(
                      tipo: 'audio',
                      titolo: 'Lettura Capitolo 1',
                      url: 'assets/media/audio_01.mp3',
                      descrizione: '',
                    ),
                    for (var i = 1; i <= 10; i++)
                      MediaItem(
                        tipo: 'testo',
                        titolo: 'Riassunto Capitolo $i',
                        url: 'assets/media/testo_01.txt',
                        descrizione: '',
                      ),
                    MediaItem(
                      tipo: 'pdf',
                      titolo: 'Pdf Capitolo 1',
                      url: 'assets/media/pdf_01.pdf',
                      descrizione: '',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildButton(
                context: context,
                color: Colors.pink.shade800,
                label: 'Antifonario',
                book: BookModel(
                  id: '123',
                  titolo: 'Antifonario',
                  autore: 'Anonimo sec. XIV',
                  anno: 'Sec. XIV',
                  multimedia: [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required Color color,
    required String label,
    required BookModel book,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onPressed: () {
          context.read<AppState>().selezionaOpera(book);
          onSimulate();
        },
        child: Text(
          label,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
