import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/app_state.dart';
import '../old/opera_repository.dart';
import '../models/models.dart';
import '../services/media_service.dart';
import '../services/recognition_service.dart';
import '../widgets/audio_widget.dart';
import '../widgets/image_widget.dart';
import '../widgets/pdf_widget.dart';
import '../widgets/text_widget.dart';
import '../widgets/video_widget.dart';

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

  double get _sS => screenSize.shortestSide;
  double get _lS => screenSize.longestSide;

  // --- MIRINO FOTOCAMERA ---
  double get viewfinderWidth =>
      (screenSize.width * 0.6).clamp(_sS * 0.35, _sS * 0.75);
  double get viewfinderHeight =>
      (screenSize.height * 0.4).clamp(_lS * 0.25, _lS * 0.5);

  // --- PANNELLO INFO OPERA ---
  Alignment get infoAlignment =>
      isLandscape ? Alignment.topRight : Alignment.topCenter;
  double get infoMaxWidth =>
      screenSize.width * (isLandscape ? 0.3 : (isTablet ? 0.75 : 0.9));
  double get infoTop => safePadding.top;
  double get infoLeft => safePadding.left + (_sS * 0.04);
  double get infoRight => safePadding.right + (_sS * 0.04);
  double get infoTitleFontSize => _sS * (isTablet ? 0.026 : 0.04);
  double get infoTextFontSize => _sS * (isTablet ? 0.018 : 0.032);
  double get infoIconSize => _sS * (isTablet ? 0.033 : 0.05);
  double get infoPadding => _sS * (isTablet ? 0.018 : 0.03);

  // --- PANNELLO BOLLE MULTIMEDIALI ---
  double get bubblesTop {
    if (isTablet && isLandscape) return safePadding.top + (_lS * 0.14);
    return isLandscape
        ? safePadding.top + (screenSize.width * 0.15)
        : safePadding.top + (_lS * (isTablet ? 0.16 : 0.13));
  }

  double get bubblesPanelWidth {
    if (isTablet && isLandscape) return _lS * 0.14;
    return isLandscape
        ? _lS * (isTablet ? 0.17 : 0.15)
        : _sS * (isTablet ? 0.11 : 0.15);
  }

  double get bubblesBottom =>
      safePadding.bottom +
      (isLandscape
          ? _sS * (isTablet ? 0.18 : 0.20)
          : _lS * (isTablet ? 0.12 : 0.12));
  double get bubblesRight =>
      safePadding.right +
      (isLandscape
          ? (isTablet ? _lS * 0.01 : _lS * 0.02)
          : _sS * (isTablet ? 0.013 : 0.04));
  double get bubblesSize => _sS * (isTablet ? 0.067 : 0.12);
  double get bubblesIconSize => _sS * (isTablet ? 0.041 : 0.06);
  double get bubblesSpacing =>
      (isTablet && isLandscape) ? _sS * 0.012 : _sS * 0.025;
  double get bubblesRunSpacing =>
      (isTablet && isLandscape) ? _sS * 0.015 : _sS * 0.03;

  // --- BOTTONE CHAT ---
  double get chatBottom =>
      safePadding.bottom + (isLandscape ? 0.0 : _lS * 0.06);
  double get chatRight => safePadding.right + (_sS * (isTablet ? 0.026 : 0.04));
  double get chatSize => _sS * (isTablet ? 0.078 : 0.14);
  double get chatIconSize => _sS * (isTablet ? 0.041 : 0.06);

  // --- BOTTONE CHIUDI ---
  double get closeBottom => safePadding.bottom;
  double get closeLeft => 0.0;
  double get closeRight => 0.0;
  double get closeSize => _sS * (isTablet ? 0.078 : 0.14);
  double get closeIconSize => _sS * (isTablet ? 0.041 : 0.06);

  // --- BOTTONE INDIETRO (LANDSCAPE) ---
  double get backTop => safePadding.top + (_sS * 0.04);
  double get backLeft => safePadding.left + (_lS * 0.02);
  double get backSize => (isTablet && isLandscape) ? _sS * 0.06 : _sS * 0.12;

  // --- MENU DEBUG ---
  double get debugTop => safePadding.top + (_lS * 0.14);
  double get debugLeft => _sS * 0.025;
  double get debugWidth =>
      (isTablet && isLandscape) ? _lS * 0.25 : screenSize.width * 0.5;
}

// ==========================================
// SCHERMATA
// ==========================================

class ARScreen extends StatefulWidget {
  final String? nomeOperaIniziale;
  const ARScreen({super.key, this.nomeOperaIniziale});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> with TickerProviderStateMixin {
  final _recognitionService = RecognitionService();
  bool _elaborazione = false;
  bool _isAutoScanning = false;
  String? _errore;
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
    _recognitionService.inizializza();

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
    _fermaScansioneAutomatica();
    _camController?.dispose();
    _fadeController.dispose();
    _scanController.dispose();
    _recognitionService.dispose();
    super.dispose();
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final opera = context.watch<AppState>().operaSelezionata;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          appBar: isLandscape
              ? null
              : AppBar(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  title: const Text(
                    'Realtà Aumentata',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
          body: _buildBody(opera),
        ),

        if (_audioInEsecuzione != null)
          Material(
            type: MaterialType.transparency,
            child: AudioWidget(
              titolo: _audioInEsecuzione!.titolo,
              audioPath: _audioInEsecuzione!.url,
              isMinimized: _audioMinimizzato,
              onMinimizeToggle: () => setState(() => _audioMinimizzato = true),
              onClose: () => setState(() => _audioInEsecuzione = null),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(BookModel? opera) {
    if (_errore != null) {
      return Center(
        child: Text(
          _errore!,
          style: const TextStyle(color: Colors.redAccent, fontSize: 18),
        ),
      );
    }

    if (!_cameraReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final layout = ARLayout(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        ARCameraFeed(controller: _camController!, layout: layout),

        if (!_overlayVisibile)
          ARCameraViewfinder(
            scanAnimation: _scanAnimation,
            layout: layout,
            isScanning: _elaborazione,
          ),

        if (kDebugMode)
          ARDebugMenu(
            layout: layout,
            onSimulate: () {
              setState(() => _audioInEsecuzione = null);
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
            onPlayAudio: (item) => setState(() {
              _audioInEsecuzione = item;
              _audioMinimizzato = false;
            }),
            onReopenAudio: () => setState(() {
              _audioMinimizzato = false;
            }),
          ),
        ],

        if (layout.isLandscape) ARBackButton(layout: layout),
      ],
    );
  }

  // --- LOGICA ---
  Future<void> _inizializzaCamera() async {
    final permesso = await Permission.camera.request();
    if (!permesso.isGranted) {
      setState(() => _errore = 'Permesso fotocamera negato');
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() => _errore = 'Nessuna fotocamera trovata');
      return;
    }

    _camController = CameraController(cameras.first, ResolutionPreset.medium);
    await _camController!.initialize();

    if (mounted) {
      setState(() => _cameraReady = true);

      if (widget.nomeOperaIniziale != null) {
        final operaTrovata = OperaRepository.tutteLeOpere().firstWhere(
          (o) => o.titolo == widget.nomeOperaIniziale,
          orElse: () => OperaRepository.tutteLeOpere().first,
        );
        context.read<AppState>().selezionaOpera(operaTrovata);
        _mostraOverlay();
      } else {
        _avviaScansioneAutomatica();
      }
    }
  }

  void _avviaScansioneAutomatica() {
    if (_isAutoScanning) return;
    _isAutoScanning = true;
    _loopScansione();
  }

  void _fermaScansioneAutomatica() {
    _isAutoScanning = false;
  }

  Future<void> _loopScansione() async {
    while (_isAutoScanning && mounted) {
      if (_cameraReady && !_overlayVisibile && !_elaborazione) {
        await _riconosci();
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _riconosci() async {
    setState(() => _elaborazione = true);

    try {
      final foto = await _camController!.takePicture();
      final bytes = await foto.readAsBytes();
      final risultato = await _recognitionService.riconosci(bytes);

      if (mounted && !_overlayVisibile) {
        if (risultato != null) {
          if (risultato.isAffidabile) {
            _fermaScansioneAutomatica();
            context.read<AppState>().riconosciOpera(risultato.nomeOpera);
            final operaTrovata = OperaRepository.trovaPerNomeML(
              risultato.nomeOpera,
            );
            context.read<AppState>().selezionaOpera(operaTrovata);

            _mostraOverlay();
          } else {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Confidenza bassa. Avvicinati all\'opera e inquadrala bene.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Errore Riconoscimento ML: $e');
    } finally {
      if (mounted) setState(() => _elaborazione = false);
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
        _avviaScansioneAutomatica();
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
    final double cameraWidth = previewSize != null
        ? (layout.isLandscape ? previewSize.width : previewSize.height)
        : layout.screenSize.width;
    final double cameraHeight = previewSize != null
        ? (layout.isLandscape ? previewSize.height : previewSize.width)
        : layout.screenSize.height;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: cameraWidth,
          height: cameraHeight,
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
  final bool isScanning;

  const ARCameraViewfinder({
    super.key,
    required this.scanAnimation,
    required this.layout,
    required this.isScanning,
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
                child: Text(
                  isScanning ? 'Analisi in corso...' : 'Punta sulla copertina',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
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
              spacing: layout.bubblesSpacing,
              runSpacing: layout.bubblesRunSpacing,
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
                  _buildBubble(context, Icons.article, 'Testi', testoList),

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
        tooltip: tipo,
        onPressed: () {
          _mostraListaMedia(context, tipo, mediaList);
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
                      '$titoloTipo (${mediaList.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                    final isAudioActive =
                        item.tipo == 'audio' && audioInEsecuzione == item;

                    return ListTile(
                      leading: Icon(
                        isAudioActive ? Icons.volume_up : Icons.arrow_right,
                        color: Colors.white70,
                        size: isAudioActive ? 20 : 24,
                      ),
                      title: Text(
                        item.titolo,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isAudioActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);

                        switch (item.tipo) {
                          case 'audio':
                            onPlayAudio(item);
                            break;

                          case 'video':
                            showDialog(
                              context: context,
                              builder: (_) => VideoWidget(
                                titolo: item.titolo,
                                videoPath: item.url,
                              ),
                            );
                            break;

                          case 'pdf':
                            showDialog(
                              context: context,
                              useSafeArea: false,
                              builder: (_) => PdfWidget(
                                titolo: item.titolo,
                                pdfPath: item.url,
                              ),
                            );
                            break;

                          case 'testo':
                            showDialog(
                              context: context,
                              builder: (_) => TextWidget(
                                titolo: item.titolo,
                                textPath: item.url,
                              ),
                            );
                            break;

                          case 'immagine':
                            showDialog(
                              context: context,
                              builder: (_) => ImageWidget(
                                immagini: mediaList,
                                initialIndex: index,
                              ),
                            );
                            break;

                          case 'link_esterno':
                          default:
                            context.read<MediaService>().apriUrl(item.url);
                            break;
                        }
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
              tooltip: 'Chiedi alla Chat',
              onPressed: () {
                context.go('/', extra: opera);
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
                tooltip: 'Chiudi',
                child: Icon(Icons.close, size: layout.closeIconSize),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- PULSANTE INDIETRO (LANDSCAPE) ---
class ARBackButton extends StatelessWidget {
  final ARLayout layout;

  const ARBackButton({super.key, required this.layout});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: layout.backTop,
      left: layout.backLeft,
      child: SizedBox(
        width: layout.backSize,
        height: layout.backSize,
        child: FloatingActionButton(
          heroTag: 'btn_back_landscape',
          backgroundColor: Colors.black.withValues(alpha: 0.75),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const CircleBorder(
            side: BorderSide(color: Colors.white24, width: 1),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back),
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
                color: Colors.pink.shade800,
                label: 'Antifonario',
                book: OperaRepository.tutteLeOpere().firstWhere(
                  (opera) => opera.titolo == 'Antifonario',
                ),
              ),

              const SizedBox(height: 8),

              _buildButton(
                context: context,
                color: Colors.cyan.shade800,
                label: 'Divina Commedia',
                book: OperaRepository.tutteLeOpere().firstWhere(
                  (opera) => opera.titolo == 'Divina Commedia',
                ),
              ),

              const SizedBox(height: 8),

              _buildButton(
                context: context,
                color: Colors.lime.shade800,
                label: 'Promessi Sposi',
                book: OperaRepository.tutteLeOpere().firstWhere(
                  (opera) => opera.titolo == 'Promessi Sposi',
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
