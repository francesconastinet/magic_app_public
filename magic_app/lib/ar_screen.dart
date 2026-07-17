import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'media_service.dart';
import 'models.dart';
import 'widgets/audio_player_widget.dart';
import 'widgets/image_dialog.dart';
import 'widgets/pdf_dialog.dart';
import 'widgets/text_dialog.dart';
import 'widgets/video_dialog.dart';

class ARScreen extends StatefulWidget {
  final String nomeOpera;
  const ARScreen({super.key, required this.nomeOpera});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> with TickerProviderStateMixin {
  bool _overlayVisibile = false;
  CameraController? _controller;
  bool _cameraReady = false;
  MediaItem? _audioInEsecuzione;
  bool _audioMinimizzato = false;

  // Animazioni
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  // --- INIZIALIZZAZIONE ---

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

  Future<void> _inizializzaCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _controller = CameraController(cameras.first, ResolutionPreset.medium);
    await _controller!.initialize();

    if (mounted) {
      setState(() => _cameraReady = true);
      // TODO: collegare a RecognitionService
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

  @override
  void dispose() {
    _controller?.dispose();
    _fadeController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  // --- COSTRUZIONE SCHERMATA ---

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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Fotocamera
        Center(child: CameraPreview(_controller!)),

        // Mirino
        if (!_overlayVisibile)
          ARCameraViewfinder(scanAnimation: _scanAnimation),

        // Menu di Debug
        if (kDebugMode)
          ARDebugMenu(
            onSimulate: () {
              setState(() {
                _audioInEsecuzione = null;
              });
              _mostraOverlay();
            },
          ),

        // Elementi in sovraimpressione
        if (_overlayVisibile && opera != null) ...[
          AROperaInfoPanel(opera: opera, fadeAnimation: _fadeAnimation),

          ARChatButton(
            overlayVisibile: _overlayVisibile,
            fadeAnimation: _fadeAnimation,
          ),

          ARCloseButton(
            overlayVisibile: _overlayVisibile,
            fadeAnimation: _fadeAnimation,
            onClose: _nascondiOverlay,
          ),

          ARMediaBubblesPanel(
            opera: opera,
            fadeAnimation: _fadeAnimation,
            onPlayAudio: (item) {
              setState(() {
                _audioInEsecuzione = item;
                _audioMinimizzato = false;
              });
            },
          ),

          // Riproduttore Audio (Espanso o Mini-Player)
          if (_audioInEsecuzione != null)
            AudioPlayerWidget(
              titolo: _audioInEsecuzione!.titolo,
              audioPath: _audioInEsecuzione!.url,
              isMinimized: _audioMinimizzato,
              onMinimizeToggle: () {
                setState(() {
                  _audioMinimizzato = !_audioMinimizzato;
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
}

// --- WIDGET ---

// Mirino animato della fotocamera
class ARCameraViewfinder extends StatelessWidget {
  final Animation<double> scanAnimation;

  const ARCameraViewfinder({super.key, required this.scanAnimation});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: scanAnimation,
        builder: (context, child) {
          return Container(
            width: 200,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: 0.4 + scanAnimation.value * 0.6,
                ),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
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

// Pannello con i dettagli dell'opera
class AROperaInfoPanel extends StatelessWidget {
  final BookModel opera;
  final Animation<double> fadeAnimation;

  const AROperaInfoPanel({
    super.key,
    required this.opera,
    required this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 24,
      left: 40,
      right: 40,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(12),
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
                children: [
                  const Icon(
                    Icons.menu_book,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      opera.titolo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
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
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Anno: ${opera.anno}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Pannello con le bubbles multimediali
class ARMediaBubblesPanel extends StatelessWidget {
  final BookModel opera;
  final Animation<double> fadeAnimation;
  final void Function(MediaItem) onPlayAudio;

  const ARMediaBubblesPanel({
    super.key,
    required this.opera,
    required this.fadeAnimation,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final fileMultimediali = opera.multimedia;
    if (fileMultimediali.isEmpty) return const SizedBox.shrink();

    return Positioned(
      right: 8,
      top: 0,
      bottom: 0,
      child: SizedBox(
        width: 75,
        child: Center(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildBubble(
                  context,
                  Icons.videocam,
                  'Video',
                  fileMultimediali.where((m) => m.tipo == 'video').toList(),
                ),
                _buildBubble(
                  context,
                  Icons.audiotrack,
                  'Audio',
                  fileMultimediali.where((m) => m.tipo == 'audio').toList(),
                ),
                _buildBubble(
                  context,
                  Icons.image,
                  'Immagini',
                  fileMultimediali.where((m) => m.tipo == 'immagine').toList(),
                ),
                _buildBubble(
                  context,
                  Icons.picture_as_pdf,
                  'PDF',
                  fileMultimediali.where((m) => m.tipo == 'pdf').toList(),
                ),
                _buildBubble(
                  context,
                  Icons.article,
                  'Testo',
                  fileMultimediali.where((m) => m.tipo == 'testo').toList(),
                ),
                _buildBubble(
                  context,
                  Icons.link,
                  'Link',
                  fileMultimediali
                      .where((m) => m.tipo == 'link_esterno')
                      .toList(),
                ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: FloatingActionButton(
        heroTag: 'bubble_$tipo',
        backgroundColor: Colors.black.withValues(alpha: 0.75),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
        onPressed: () => _mostraListaMedia(context, tipo, mediaList),
        child: Icon(icona),
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
                                  titolo: item.titolo,
                                  imagePath: item.url,
                                );
                              case 'video':
                                return VideoDialog(
                                  titolo: item.titolo,
                                  videoPath: item.url,
                                );
                              case 'pdf':
                                return PdfDialog(
                                  titolo: item.titolo,
                                  pdfPath: item.url,
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

// Pulsante per aprire la chat contestuale
class ARChatButton extends StatelessWidget {
  final bool overlayVisibile;
  final Animation<double> fadeAnimation;

  const ARChatButton({
    super.key,
    required this.overlayVisibile,
    required this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 116,
      right: 8,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: IgnorePointer(
          ignoring: !overlayVisibile,
          child: SizedBox(
            width: 75,
            height: 75,
            child: FloatingActionButton(
              heroTag: 'btn_chat',
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              onPressed: () {
                // TODO: aprire la Chat
              },
              child: const Icon(Icons.chat_bubble, size: 34),
            ),
          ),
        ),
      ),
    );
  }
}

// Pulsante per chiudere l'overlay
class ARCloseButton extends StatelessWidget {
  final bool overlayVisibile;
  final Animation<double> fadeAnimation;
  final VoidCallback onClose;

  const ARCloseButton({
    super.key,
    required this.overlayVisibile,
    required this.fadeAnimation,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: fadeAnimation,
          child: IgnorePointer(
            ignoring: !overlayVisibile,
            child: FloatingActionButton(
              heroTag: 'btn_chiudi',
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const CircleBorder(
                side: BorderSide(color: Colors.white24, width: 1),
              ),
              onPressed: onClose,
              child: const Icon(Icons.close, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

// Menu di debug (visibile solo in fase di sviluppo)
class ARDebugMenu extends StatelessWidget {
  final VoidCallback onSimulate;

  const ARDebugMenu({super.key, required this.onSimulate});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 200,
      left: 4,
      right: 260,
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
              _buildDebugButton(
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
              _buildDebugButton(
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
                      titolo: 'Lettura Canto I',
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
                      titolo: 'Pdf Canto I',
                      url: 'assets/media/pdf_01.pdf',
                      descrizione: '',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildDebugButton(
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

  Widget _buildDebugButton({
    required BuildContext context,
    required Color color,
    required String label,
    required BookModel book,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () {
        context.read<AppState>().selezionaOpera(book);
        onSimulate();
      },
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
