import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../app_config.dart';
import '../services/package_storage.dart';

// ==========================================
// CONFIGURAZIONE LAYOUT
// ==========================================

class AudioLayout {
  final Size screenSize;
  final bool isLandscape;
  final bool isTablet;

  AudioLayout(BuildContext context)
    : screenSize = MediaQuery.sizeOf(context),
      isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape,
      isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

  double get _sS => screenSize.shortestSide;
  double get _lS => screenSize.longestSide;

  // --- DIMENSIONI CONTAINER ---
  double get containerWidth => isLandscape
      ? (isTablet ? _lS * 0.35 : _lS * 0.45)
      : (isTablet ? _sS * 0.6 : _sS * 0.85);
  double get maxContainerHeight => isLandscape ? _sS * 0.75 : _lS * 0.85;

  // --- SPAZIATURE ---
  double get verticalSpacing => isLandscape ? _sS * 0.02 : _lS * 0.02;
  double get padding => isTablet ? _sS * 0.04 : _sS * 0.05;
  double get borderRadius => _sS * 0.04;

  // --- ICONE E TESTI ---
  double get mainIconSize => _sS * 0.1;
  double get headerIconSize => _sS * (isTablet ? 0.04 : 0.06);
  double get titleFontSize => _sS * (isTablet ? 0.03 : 0.045);
  double get timeFontSize => _sS * (isTablet ? 0.025 : 0.035);

  // --- PULSANTE PLAY/PAUSE ---
  double get playRadius => isLandscape ? _sS * 0.05 : _sS * 0.07;
  double get playIconSize => isLandscape ? _sS * 0.06 : _sS * 0.08;
}

// ==========================================
// SCHERMATA
// ==========================================

class AudioWidget extends StatefulWidget {
  final String titolo;
  final String audioPath;
  final bool isMinimized;
  final VoidCallback onMinimizeToggle;
  final VoidCallback onClose;

  const AudioWidget({
    super.key,
    required this.titolo,
    required this.audioPath,
    required this.isMinimized,
    required this.onMinimizeToggle,
    required this.onClose,
  });

  @override
  State<AudioWidget> createState() => _AudioWidgetState();
}

class _AudioWidgetState extends State<AudioWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _inizializzaAudio();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    if (widget.isMinimized) {
      return const SizedBox.shrink();
    }

    final layout = AudioLayout(context);

    return ExpandedAudioPlayer(
      titolo: widget.titolo,
      isPlaying: _isPlaying,
      duration: _duration,
      position: _position,
      layout: layout,
      onTogglePlay: _togglePlayPause,
      onSeek: (value) async {
        final position = Duration(seconds: value.toInt());
        await _audioPlayer.seek(position);
      },
      onMinimize: widget.onMinimizeToggle,
      onClose: widget.onClose,
    );
  }

  // --- LOGICA ---
  Future<void> _inizializzaAudio() async {
    try {
      // CASO 1: Modalità Test (File negli asset)
      // TODO: rimuovere quando il client sarà collegato al backend
      if (widget.audioPath.startsWith('assets/')) {
        final assetPath = widget.audioPath.replaceFirst('assets/', '');
        await _audioPlayer.setSource(AssetSource(assetPath));
      }
      // CASO 2: Modalità Produzione (File estratti su disco dallo ZIP)
      else {
        final storageService = context.read<PackageStorage>();
        final basePath = await storageService.percorsoPacchetto(
          AppConfig.packageId,
        );
        final percorsoAssoluto = '$basePath/${widget.audioPath}';
        await _audioPlayer.setSourceDeviceFile(percorsoAssoluto);
      }
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Errore caricamento audio: $e');
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.resume();
    }
  }
}

// ==========================================
// WIDGET
// ==========================================

// --- PLAYER ---
class ExpandedAudioPlayer extends StatelessWidget {
  final String titolo;
  final bool isPlaying;
  final Duration duration;
  final Duration position;
  final AudioLayout layout;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSeek;
  final VoidCallback onMinimize;
  final VoidCallback onClose;

  const ExpandedAudioPlayer({
    super.key,
    required this.titolo,
    required this.isPlaying,
    required this.duration,
    required this.position,
    required this.layout,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onMinimize,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: SafeArea(
          minimum: EdgeInsets.symmetric(vertical: layout.borderRadius),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: layout.containerWidth,
                maxHeight: layout.maxContainerHeight,
              ),
              child: Container(
                padding: EdgeInsets.only(
                  top: layout.verticalSpacing,
                  bottom: layout.verticalSpacing + layout.borderRadius,
                  left: layout.padding,
                  right: layout.padding,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(layout.borderRadius),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExpandedPlayerHeader(
                        onMinimize: onMinimize,
                        onClose: onClose,
                        layout: layout,
                      ),

                      ExpandedPlayerTitle(titolo: titolo, layout: layout),

                      SizedBox(height: layout.verticalSpacing),

                      Icon(
                        Icons.audiotrack,
                        size: layout.mainIconSize,
                        color: Colors.blueAccent,
                      ),

                      SizedBox(height: layout.verticalSpacing),

                      AudioProgressBar(
                        duration: duration,
                        position: position,
                        onSeek: onSeek,
                        layout: layout,
                      ),

                      SizedBox(height: layout.verticalSpacing),

                      AudioPlayPauseButton(
                        isPlaying: isPlaying,
                        onTogglePlay: onTogglePlay,
                        layout: layout,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- HEADER ---
class ExpandedPlayerHeader extends StatelessWidget {
  final VoidCallback onMinimize;
  final VoidCallback onClose;
  final AudioLayout layout;

  const ExpandedPlayerHeader({
    super.key,
    required this.onMinimize,
    required this.onClose,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white54,
            size: layout.headerIconSize,
          ),
          onPressed: onMinimize,
        ),

        IconButton(
          icon: Icon(
            Icons.close,
            color: Colors.redAccent,
            size: layout.headerIconSize,
          ),
          onPressed: onClose,
        ),
      ],
    );
  }
}

// --- TITOLO ---
class ExpandedPlayerTitle extends StatelessWidget {
  final String titolo;
  final AudioLayout layout;

  const ExpandedPlayerTitle({
    super.key,
    required this.titolo,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        titolo,
        style: TextStyle(
          color: Colors.white,
          fontSize: layout.titleFontSize,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// --- BARRA PROGRESSIONE ---
class AudioProgressBar extends StatelessWidget {
  final Duration duration;
  final Duration position;
  final ValueChanged<double> onSeek;
  final AudioLayout layout;

  const AudioProgressBar({
    super.key,
    required this.duration,
    required this.position,
    required this.onSeek,
    required this.layout,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slider(
          activeColor: Colors.blueAccent,
          inactiveColor: Colors.white24,
          min: 0.0,
          max: duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0,
          value: position.inSeconds.toDouble().clamp(
            0.0,
            duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0,
          ),
          onChanged: onSeek,
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(position),
              style: TextStyle(
                color: Colors.white54,
                fontSize: layout.timeFontSize,
              ),
            ),

            Text(
              _formatDuration(duration),
              style: TextStyle(
                color: Colors.white54,
                fontSize: layout.timeFontSize,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- PULSANTE PLAY/PAUSA ---
class AudioPlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final AudioLayout layout;

  const AudioPlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: layout.playRadius,
      backgroundColor: Colors.blueAccent,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: layout.playIconSize,
        ),
        onPressed: onTogglePlay,
      ),
    );
  }
}
