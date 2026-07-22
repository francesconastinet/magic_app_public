import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../package_storage.dart';
import '../app_config.dart';

// ==========================================
// SCHERMATA PLAYER
// ==========================================

class VideoDialog extends StatefulWidget {
  final String titolo;
  final String videoPath;

  const VideoDialog({super.key, required this.titolo, required this.videoPath});

  @override
  State<VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<VideoDialog> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _mostraControlli = true;
  Timer? _timerNascondiControlli;

  // --- INIZIALIZZAZIONE ---
  @override
  void initState() {
    super.initState();
    _inizializzaVideo();
  }

  Future<void> _inizializzaVideo() async {
    try {
      // CASO 1: File negli asset (Modalità Test)
      // TODO: rimuovere quando il client sarà collegato al backend
      if (widget.videoPath.startsWith('assets/')) {
        _controller = VideoPlayerController.asset(widget.videoPath);
      }
      // CASO 2: File nel file system (Scaricato dallo ZIP)
      else {
        final storageService = context.read<PackageStorage>();
        final basePath = await storageService.percorsoPacchetto(
          AppConfig.packageId,
        );
        final percorsoAssoluto = '$basePath/${widget.videoPath}';

        _controller = VideoPlayerController.file(File(percorsoAssoluto));
      }

      await _controller!.initialize();

      if (mounted) {
        setState(() => _isInitialized = true);
        _controller!.play();
        _avviaTimerNascondiControlli();
      }
    } catch (e) {
      debugPrint('Errore caricamento video: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _timerNascondiControlli?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isTablet = screenSize.shortestSide >= 600;

    final double adaptiveMaxWidth = isTablet
        ? (isLandscape ? screenSize.width * 0.75 : screenSize.width * 0.9)
        : (isLandscape ? screenSize.width * 0.7 : screenSize.width * 0.9);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: adaptiveMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VideoDialogHeader(
              titolo: widget.titolo,
              onClose: () => Navigator.pop(context),
            ),
            Flexible(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Center(heightFactor: 1.0, child: _buildVideoContent()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_hasError) return const VideoErrorState();
    if (!_isInitialized || _controller == null) {
      return const VideoLoadingState();
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: GestureDetector(
          onTap: _toggleControlli,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(_controller!),
              VideoControlOverlay(
                controller: _controller!,
                mostraControlli: _mostraControlli,
                onJump: (secondi) {
                  _salta(secondi);
                  _avviaTimerNascondiControlli();
                },
                onTogglePlay: () {
                  setState(() {
                    if (_controller!.value.isPlaying) {
                      _controller!.pause();
                      _timerNascondiControlli?.cancel();
                    } else {
                      _controller!.play();
                      _avviaTimerNascondiControlli();
                    }
                  });
                },
                onDragStart: () => _timerNascondiControlli?.cancel(),
                onDragEnd: () => _avviaTimerNascondiControlli(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- LOGICA ---
  Future<void> _salta(int secondi) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final posizioneCorrente = await _controller!.position;
    if (posizioneCorrente != null) {
      final nuovaPosizione = posizioneCorrente + Duration(seconds: secondi);
      await _controller!.seekTo(nuovaPosizione);
    }
  }

  void _toggleControlli() {
    setState(() {
      _mostraControlli = !_mostraControlli;
    });

    if (_mostraControlli) {
      _avviaTimerNascondiControlli();
    } else {
      _timerNascondiControlli?.cancel();
    }
  }

  void _avviaTimerNascondiControlli() {
    _timerNascondiControlli?.cancel();

    if (_controller != null && !_controller!.value.isPlaying) return;

    _timerNascondiControlli = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _mostraControlli = false);
      }
    });
  }
}

// ==========================================
// WIDGET
// ==========================================

// --- HEADER ---
class VideoDialogHeader extends StatelessWidget {
  final String titolo;
  final VoidCallback onClose;

  const VideoDialogHeader({
    super.key,
    required this.titolo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titolo,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
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
  const VideoErrorState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 8),
            Text(
              'Impossibile riprodurre il video',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// --- SCHERMATA CARICAMENTO ---
class VideoLoadingState extends StatelessWidget {
  const VideoLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(64.0),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

// --- OVERLAY CONTROLLI ---
class VideoControlOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final bool mostraControlli;
  final Function(int) onJump;
  final VoidCallback onTogglePlay;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const VideoControlOverlay({
    super.key,
    required this.controller,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              VideoPlaybackButtons(
                isPlaying: controller.value.isPlaying,
                onJump: onJump,
                onTogglePlay: onTogglePlay,
              ),
              const SizedBox(height: 16),
              VideoProgressBar(
                controller: controller,
                onDragStart: onDragStart,
                onDragEnd: onDragEnd,
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
  final bool isPlaying;
  final Function(int) onJump;
  final VoidCallback onTogglePlay;

  const VideoPlaybackButtons({
    super.key,
    required this.isPlaying,
    required this.onJump,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              iconSize: 36,
              color: Colors.white,
              icon: const Icon(Icons.replay_5),
              onPressed: () => onJump(-5),
            ),
            const SizedBox(width: 16),
            IconButton(
              iconSize: 56,
              color: Colors.white,
              icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
              onPressed: onTogglePlay,
            ),
            const SizedBox(width: 16),
            IconButton(
              iconSize: 36,
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

// --- BARRA PROGRESSIONE ---
class VideoProgressBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, VideoPlayerValue value, child) {
        final pos = value.position.inMilliseconds.toDouble();
        final dur = value.duration.inMilliseconds.toDouble();

        return Slider(
          activeColor: Colors.redAccent,
          inactiveColor: Colors.white54,
          min: 0.0,
          max: dur > 0 ? dur : 1.0,
          value: pos.clamp(0.0, dur > 0 ? dur : 1.0),
          onChangeStart: (_) => onDragStart(),
          onChanged: (nuovoValore) async {
            final nuovaPosizione = Duration(milliseconds: nuovoValore.toInt());
            await controller.seekTo(nuovaPosizione);
          },
          onChangeEnd: (_) => onDragEnd(),
        );
      },
    );
  }
}
