import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../viewmodels/video_viewmodel.dart';

// ==========================================
// SCHERMATA
// ==========================================

class VideoView extends StatefulWidget {
  final String titolo;
  final String videoPath;

  const VideoView({super.key, required this.titolo, required this.videoPath});

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  late VideoViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = VideoViewModel(storageService: context.read<StorageService>());
    _viewModel.inizializzaVideo(widget.videoPath);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final layout = VideoLayout(context);

    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<VideoViewModel>(
        builder: (context, vm, child) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.all(layout.dialogInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.adaptiveMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  VideoDialogHeader(
                    titolo: widget.titolo,
                    layout: layout,
                    onClose: () => Navigator.pop(context),
                  ),
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(layout.borderRadius),
                        ),
                      ),
                      child: Center(
                        heightFactor: 1.0,
                        child: _buildVideoContent(layout, vm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoContent(VideoLayout layout, VideoViewModel vm) {
    double safeRatio = 16 / 9;

    if (vm.controller != null && vm.controller!.value.isInitialized) {
      final size = vm.controller!.value.size;
      if (size.width > 0 && size.height > 0) {
        safeRatio = size.width / size.height;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(layout.borderRadius),
      ),
      child: AspectRatio(
        aspectRatio: safeRatio,
        child: _buildVideoState(layout, vm),
      ),
    );
  }

  Widget _buildVideoState(VideoLayout layout, VideoViewModel vm) {
    if (vm.hasError) return VideoErrorState(layout: layout);
    if (!vm.isInitialized || vm.controller == null) {
      return VideoLoadingState(layout: layout);
    }

    return GestureDetector(
      onTap: vm.toggleControlli,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(vm.controller!),
          VideoControlOverlay(
            controller: vm.controller!,
            layout: layout,
            mostraControlli: vm.mostraControlli,
            onJump: (secondi) {
              vm.salta(secondi);
              vm.avviaTimerNascondiControlli();
            },
            onTogglePlay: vm.togglePlay,
            onDragStart: vm.fermaTimerControlli,
            onDragEnd: vm.avviaTimerNascondiControlli,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CONFIGURAZIONE LAYOUT
// ==========================================

class VideoLayout {
  final Size screenSize;
  final bool isLandscape;
  final bool isTablet;

  VideoLayout(BuildContext context)
    : screenSize = MediaQuery.sizeOf(context),
      isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape,
      isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

  double get _sS => screenSize.shortestSide;

  // --- DIMENSIONI SCHERMATA ---
  double get adaptiveMaxWidth => isTablet
      ? (isLandscape ? screenSize.width * 0.75 : screenSize.width * 0.9)
      : (isLandscape ? screenSize.width * 0.7 : screenSize.width * 0.9);
  double get dialogInset => _sS * 0.04;
  double get borderRadius => _sS * 0.03;

  // --- HEADER ---
  double get headerPadH => _sS * 0.03;
  double get headerPadV => _sS * 0.02;
  double get headerFontSize => _sS * (isTablet ? 0.03 : 0.04);
  double get headerIconSize => _sS * (isTablet ? 0.04 : 0.06);

  // --- ERRORE E CARICAMENTO ---
  double get errorIconSize => _sS * (isTablet ? 0.08 : 0.12);
  double get errorSpacing => _sS * 0.02;
  double get errorFontSize => _sS * (isTablet ? 0.025 : 0.035);
  double get statePaddingMedium => _sS * 0.08;
  double get statePaddingLarge => _sS * 0.16;

  // --- OVERLAY CONTROLLI ---
  double get controlSpacing => _sS * 0.04;
  double get controlPadH => _sS * 0.04;
  double get controlPadV => _sS * 0.02;
  double get controlRadius => _sS * 0.075;
  double get smallIconSize => _sS * (isTablet ? 0.06 : 0.09);
  double get largeIconSize => _sS * (isTablet ? 0.09 : 0.14);
}

// ==========================================
// WIDGET
// ==========================================

// --- HEADER ---
class VideoDialogHeader extends StatelessWidget {
  final String titolo;
  final VideoLayout layout;
  final VoidCallback onClose;

  const VideoDialogHeader({
    super.key,
    required this.titolo,
    required this.layout,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.headerPadH,
        vertical: layout.headerPadV,
      ),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(layout.borderRadius),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titolo,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: layout.headerFontSize,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.white,
              size: layout.headerIconSize,
            ),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// --- SCHERMATA ERRORE ---
class VideoErrorState extends StatelessWidget {
  final VideoLayout layout;

  const VideoErrorState({super.key, required this.layout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(layout.statePaddingMedium),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: layout.errorIconSize,
            ),

            SizedBox(height: layout.errorSpacing),

            Text(
              'Impossibile riprodurre il video',
              style: TextStyle(
                color: Colors.white70,
                fontSize: layout.errorFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- SCHERMATA CARICAMENTO ---
class VideoLoadingState extends StatelessWidget {
  final VideoLayout layout;

  const VideoLoadingState({super.key, required this.layout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(layout.statePaddingLarge),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

// --- OVERLAY CONTROLLI ---
class VideoControlOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final VideoLayout layout;
  final bool mostraControlli;
  final Function(int) onJump;
  final VoidCallback onTogglePlay;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const VideoControlOverlay({
    super.key,
    required this.controller,
    required this.layout,
    required this.mostraControlli,
    required this.onJump,
    required this.onTogglePlay,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: mostraControlli ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !mostraControlli,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: VideoPlaybackButtons(
                  layout: layout,
                  isPlaying: controller.value.isPlaying,
                  onJump: onJump,
                  onTogglePlay: onTogglePlay,
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: layout.controlPadV,
                child: VideoProgressBar(
                  controller: controller,
                  onDragStart: onDragStart,
                  onDragEnd: onDragEnd,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- CONTROLLI PLAYER ---
class VideoPlaybackButtons extends StatelessWidget {
  final VideoLayout layout;
  final bool isPlaying;
  final Function(int) onJump;
  final VoidCallback onTogglePlay;

  const VideoPlaybackButtons({
    super.key,
    required this.layout,
    required this.isPlaying,
    required this.onJump,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: layout.controlPadH,
          vertical: layout.controlPadV,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(layout.controlRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              iconSize: layout.smallIconSize,
              color: Colors.white,
              icon: const Icon(Icons.replay_5),
              onPressed: () => onJump(-5),
            ),

            SizedBox(width: layout.controlSpacing),

            IconButton(
              iconSize: layout.largeIconSize,
              color: Colors.white,
              icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
              onPressed: onTogglePlay,
            ),

            SizedBox(width: layout.controlSpacing),

            IconButton(
              iconSize: layout.smallIconSize,
              color: Colors.white,
              icon: const Icon(Icons.forward_5),
              onPressed: () => onJump(5),
            ),
          ],
        ),
      ),
    );
  }
}

// --- BARRA PROGRESSO ---
class VideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const VideoProgressBar({
    super.key,
    required this.controller,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller,
      builder: (context, VideoPlayerValue value, child) {
        final pos = value.position.inMilliseconds.toDouble();
        final dur = value.duration.inMilliseconds.toDouble();

        return Slider(
          activeColor: Colors.redAccent,
          inactiveColor: Colors.white54,
          min: 0.0,
          max: dur > 0 ? dur : 1.0,
          value: (_dragValue ?? pos).clamp(0.0, dur > 0 ? dur : 1.0),

          onChangeStart: (nuovoValore) {
            widget.onDragStart();
            setState(() {
              _dragValue = nuovoValore;
            });
          },

          onChanged: (nuovoValore) {
            setState(() {
              _dragValue = nuovoValore;
            });
          },

          onChangeEnd: (nuovoValore) async {
            final nuovaPosizione = Duration(milliseconds: nuovoValore.toInt());
            await widget.controller.seekTo(nuovaPosizione);
            setState(() {
              _dragValue = null;
            });
            widget.onDragEnd();
          },
        );
      },
    );
  }
}
