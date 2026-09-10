import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import '../core/app_state.dart';
import '../data/catalogue_repository.dart';
import '../data/models.dart';
import '../services/media_service.dart';
import 'audio_widget.dart';
import 'image_widget.dart';
import 'pdf_widget.dart';
import 'text_widget.dart';
import 'video_widget.dart';
import '../viewmodels/ar_viewmodel.dart';

// ==========================================
// SCHERMATA
// ==========================================

class ARView extends StatefulWidget {
  final String? nomeOperaIniziale;
  const ARView({super.key, this.nomeOperaIniziale});

  @override
  State<ARView> createState() => _ARViewState();
}

class _ARViewState extends State<ARView> with TickerProviderStateMixin {
  late ARViewModel _viewModel;
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

    _viewModel = ARViewModel(repository: context.read<CatalogueRepository>());

    _viewModel.onShowWarning = (msg) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.orange),
      );
    };

    _viewModel.onShowError = (msg) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    };

    _viewModel.onMostraOverlayAnimation = () {
      _scanController.stop();
      _fadeController.forward();
    };

    _viewModel.onNascondiOverlayAnimation = () {
      _fadeController.reverse().then((_) {
        if (mounted) {
          _scanController.repeat(reverse: true);
          _viewModel.onAnimazioneChiusuraCompletata();
        }
      });
    };

    _viewModel.inizializzaCamera(nomeOperaIniziale: widget.nomeOperaIniziale);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scanController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<ARViewModel>(
        builder: (context, vm, child) {
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                body: _buildBody(vm),
              ),

              if (vm.audioInEsecuzione != null)
                Material(
                  type: MaterialType.transparency,
                  child: AudioWidget(
                    titolo: vm.audioInEsecuzione!.titolo,
                    audioPath: vm.audioInEsecuzione!.url,
                    isMinimized: vm.audioMinimizzato,
                    onMinimizeToggle: () => vm.impostaAudio(
                      vm.audioInEsecuzione,
                      minimizzato: true,
                    ),
                    onClose: () => vm.impostaAudio(null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(ARViewModel vm) {
    if (vm.errore != null) {
      return Center(
        child: Text(
          vm.errore!,
          style: const TextStyle(color: Colors.redAccent, fontSize: 18),
        ),
      );
    }

    if (!vm.cameraReady || vm.camController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final layout = ARLayout(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        ARCameraFeed(controller: vm.camController!, layout: layout),

        if (!vm.overlayVisibile)
          ARCameraViewfinder(
            scanAnimation: _scanAnimation,
            layout: layout,
            isScanning: vm.elaborazione,
          ),

        if (kDebugMode)
          ARDebugMenu(
            layout: layout,
            onSimulate: (book) => vm.simulaRiconoscimento(book),
          ),

        if (vm.overlayVisibile && vm.operaRiconosciuta != null) ...[
          AROperaInfoPanel(
            opera: vm.operaRiconosciuta!,
            fadeAnimation: _fadeAnimation,
            layout: layout,
          ),
          ARChatButton(
            opera: vm.operaRiconosciuta!,
            overlayVisibile: vm.overlayVisibile,
            fadeAnimation: _fadeAnimation,
            layout: layout,
          ),
          ARCloseButton(
            overlayVisibile: vm.overlayVisibile,
            fadeAnimation: _fadeAnimation,
            layout: layout,
            onClose: vm.nascondiOverlay,
          ),
          ARMediaBubblesPanel(
            opera: vm.operaRiconosciuta!,
            fadeAnimation: _fadeAnimation,
            layout: layout,
            audioInEsecuzione: vm.audioInEsecuzione,
            onPlayAudio: (item) => vm.impostaAudio(item, minimizzato: false),
            onReopenAudio: () =>
                vm.impostaAudio(vm.audioInEsecuzione, minimizzato: false),
          ),
        ],

        if (layout.isLandscape) ARBackButton(layout: layout),
      ],
    );
  }
}

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
  double get infoRight =>
      safePadding.right +
      (isTablet ? (isLandscape ? _sS * 0.05 : _sS * 0.04) : _sS * 0.04);
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
          ? (isTablet ? _sS * 0.03 : _lS * 0.01)
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
  double get chatRight =>
      safePadding.right +
      (_sS * (isTablet ? (isLandscape ? 0.05 : 0.026) : 0.04));
  double get chatSize => _sS * (isTablet ? 0.078 : 0.14);
  double get chatIconSize => _sS * (isTablet ? 0.041 : 0.07);

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
  double get debugTop => safePadding.top + (_lS * 0.16);
  double get debugLeft => _sS * 0.02;
  double get debugWidth => isLandscape ? _lS * 0.25 : screenSize.width * 0.45;
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
    double cameraRatio = controller.value.aspectRatio;

    if (!layout.isLandscape) {
      cameraRatio = 1 / cameraRatio;
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: 100,
          height: 100 / cameraRatio,
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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: layout.infoTitleFontSize * 1.2 * 2.5,
                    ),
                    child: RawScrollbar(
                      thumbColor: Colors.white54,
                      thickness: 3,
                      radius: const Radius.circular(8),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            opera.titolo,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: layout.infoTitleFontSize,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

    final videoList = fileMultimediali
        .where((m) => m.tipo == MediaType.video)
        .toList();
    final audioList = fileMultimediali
        .where((m) => m.tipo == MediaType.audio)
        .toList();
    final immaginiList = fileMultimediali
        .where((m) => m.tipo == MediaType.immagine)
        .toList();
    final pdfList = fileMultimediali
        .where((m) => m.tipo == MediaType.pdf)
        .toList();
    final testoList = fileMultimediali
        .where((m) => m.tipo == MediaType.testo)
        .toList();
    final linkList = fileMultimediali
        .where((m) => m.tipo == MediaType.linkEsterno)
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
                  _buildBubble(
                    context,
                    Icons.videocam,
                    MediaType.video,
                    videoList,
                  ),

                if (audioList.isNotEmpty)
                  _buildBubble(
                    context,
                    Icons.audiotrack,
                    MediaType.audio,
                    audioList,
                  ),

                if (immaginiList.isNotEmpty)
                  _buildBubble(
                    context,
                    Icons.image,
                    MediaType.immagine,
                    immaginiList,
                  ),

                if (pdfList.isNotEmpty)
                  _buildBubble(
                    context,
                    Icons.picture_as_pdf,
                    MediaType.pdf,
                    pdfList,
                  ),

                if (testoList.isNotEmpty)
                  _buildBubble(
                    context,
                    Icons.article,
                    MediaType.testo,
                    testoList,
                  ),

                if (linkList.isNotEmpty)
                  _buildBubble(
                    context,
                    Icons.link,
                    MediaType.linkEsterno,
                    linkList,
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
    MediaType tipo,
    List<MediaItem> mediaList,
  ) {
    if (mediaList.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: layout.bubblesSize,
      height: layout.bubblesSize,
      child: FloatingActionButton(
        heroTag: 'bubble_${tipo.name}',
        backgroundColor: Colors.black.withValues(alpha: 0.75),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
        tooltip: getTitoloTipo(tipo),
        onPressed: () {
          _mostraListaMedia(context, tipo, mediaList);
        },
        child: Icon(icona, size: layout.bubblesIconSize),
      ),
    );
  }

  void _mostraListaMedia(
    BuildContext context,
    MediaType tipo,
    List<MediaItem> mediaList,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => MediaSelectionBottomSheet(
        titoloTipo: getTitoloTipo(tipo),
        mediaList: mediaList,
        audioInEsecuzione: audioInEsecuzione,
        onPlayAudio: onPlayAudio,
      ),
    );
  }
}

// --- LISTA FILE MULTIMEDIALI ---
class MediaSelectionBottomSheet extends StatelessWidget {
  final String titoloTipo;
  final List<MediaItem> mediaList;
  final MediaItem? audioInEsecuzione;
  final ValueChanged<MediaItem> onPlayAudio;

  const MediaSelectionBottomSheet({
    super.key,
    required this.titoloTipo,
    required this.mediaList,
    required this.audioInEsecuzione,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
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
                    item.tipo == MediaType.audio && audioInEsecuzione == item;

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
                    _gestisciTapMedia(context, item, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _gestisciTapMedia(BuildContext context, MediaItem item, int index) {
    switch (item.tipo) {
      case MediaType.audio:
        onPlayAudio(item);
        break;

      case MediaType.video:
        showDialog(
          context: context,
          builder: (_) => VideoWidget(titolo: item.titolo, videoPath: item.url),
        );
        break;

      case MediaType.pdf:
        showDialog(
          context: context,
          useSafeArea: false,
          builder: (_) => PdfWidget(titolo: item.titolo, pdfPath: item.url),
        );
        break;

      case MediaType.testo:
        showDialog(
          context: context,
          builder: (_) => TextWidget(titolo: item.titolo, textPath: item.url),
        );
        break;

      case MediaType.immagine:
        showDialog(
          context: context,
          builder: (_) => ImageWidget(immagini: mediaList, initialIndex: index),
        );
        break;

      case MediaType.linkEsterno:
        context.read<MediaService>().apriUrl(item.url);
        break;
    }
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
                context.read<AppState>().selezionaOpera(opera);
                context.go('/');
              },
              child: Icon(Icons.contact_support, size: layout.chatIconSize),
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
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          child: const Icon(Icons.arrow_back),
        ),
      ),
    );
  }
}

// --- MENU DEBUG ---
class ARDebugMenu extends StatelessWidget {
  final void Function(BookModel book) onSimulate;
  final ARLayout layout;

  const ARDebugMenu({
    super.key,
    required this.onSimulate,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    final libriScaricati = context
        .read<CatalogueRepository>()
        .libri
        .take(3)
        .toList();
    final List<Color> colori = [
      Colors.pink.shade800,
      Colors.cyan.shade800,
      Colors.lime.shade800,
    ];

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

              if (libriScaricati.isEmpty)
                const Text(
                  'Nessun libro',
                  style: TextStyle(color: Colors.white),
                ),

              ...List.generate(libriScaricati.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildButton(
                    context: context,
                    color: colori[index % colori.length],
                    label: libriScaricati[index].titolo,
                    book: libriScaricati[index],
                  ),
                );
              }),
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
          onSimulate(book);
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
