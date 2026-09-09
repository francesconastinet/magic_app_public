import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/app_config.dart';
import '../services/storage_service.dart';

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

  // --- DIMENSIONI SCHERMATA ---
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

  StreamSubscription? _stateSub;
  StreamSubscription? _durSub;
  StreamSubscription? _posSub;

  final ValueNotifier<Duration> _durationNotifier = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(
    Duration.zero,
  );

  @override
  void initState() {
    super.initState();
    _inizializzaAudio();

    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    _durSub = _audioPlayer.onDurationChanged.listen((duration) {
      _durationNotifier.value = duration;
    });

    _posSub = _audioPlayer.onPositionChanged.listen((position) {
      _positionNotifier.value = position;
    });
  }

  @override
  void didUpdateWidget(covariant AudioWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioPath != widget.audioPath) {
      _audioPlayer.stop();
      _isPlaying = false;
      _durationNotifier.value = Duration.zero;
      _positionNotifier.value = Duration.zero;
      _inizializzaAudio();
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _durSub?.cancel();
    _posSub?.cancel();
    _durationNotifier.dispose();
    _positionNotifier.dispose();
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
      audioPlayer: _audioPlayer,
      durationNotifier: _durationNotifier,
      positionNotifier: _positionNotifier,
      layout: layout,
      onTogglePlay: _togglePlayPause,
      onMinimize: widget.onMinimizeToggle,
      onClose: widget.onClose,
    );
  }

  // --- LOGICA ---
  Future<void> _inizializzaAudio() async {
    try {
      if (widget.audioPath.startsWith('assets/')) {
        final assetPath = widget.audioPath.replaceFirst('assets/', '');
        await _audioPlayer.setSource(AssetSource(assetPath));
      } else {
        final storageService = context.read<StorageService>();
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
  final AudioPlayer audioPlayer;
  final ValueNotifier<Duration> durationNotifier;
  final ValueNotifier<Duration> positionNotifier;
  final AudioLayout layout;
  final VoidCallback onTogglePlay;
  final VoidCallback onMinimize;
  final VoidCallback onClose;

  const ExpandedAudioPlayer({
    super.key,
    required this.titolo,
    required this.isPlaying,
    required this.audioPlayer,
    required this.durationNotifier,
    required this.positionNotifier,
    required this.layout,
    required this.onTogglePlay,
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
                        audioPlayer: audioPlayer,
                        durationNotifier: durationNotifier,
                        positionNotifier: positionNotifier,
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
  final AudioPlayer audioPlayer;
  final ValueNotifier<Duration> durationNotifier;
  final ValueNotifier<Duration> positionNotifier;
  final AudioLayout layout;

  const AudioProgressBar({
    super.key,
    required this.audioPlayer,
    required this.durationNotifier,
    required this.positionNotifier,
    required this.layout,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: durationNotifier,
      builder: (context, duration, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: positionNotifier,
          builder: (context, position, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  activeColor: Colors.blueAccent,
                  inactiveColor: Colors.white24,
                  min: 0.0,
                  max: duration.inSeconds > 0
                      ? duration.inSeconds.toDouble()
                      : 1.0,
                  value: position.inSeconds.toDouble().clamp(
                    0.0,
                    duration.inSeconds > 0
                        ? duration.inSeconds.toDouble()
                        : 1.0,
                  ),
                  onChanged: (valore) async {
                    await audioPlayer.seek(Duration(seconds: valore.toInt()));
                  },
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
          },
        );
      },
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
