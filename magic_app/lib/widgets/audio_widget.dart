import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../package_storage.dart';

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

  // --- INIZIALIZZAZIONE ---

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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- COSTRUZIONE SCHERMATA ---

  @override
  Widget build(BuildContext context) {
    if (widget.isMinimized) {
      return MiniAudioPlayer(
        titolo: widget.titolo,
        isPlaying: _isPlaying,
        onTogglePlay: _togglePlayPause,
        onExpand: widget.onMinimizeToggle,
        onClose: widget.onClose,
      );
    }

    return ExpandedAudioPlayer(
      titolo: widget.titolo,
      isPlaying: _isPlaying,
      duration: _duration,
      position: _position,
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

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.resume();
    }
  }
}

// --- WIDGET ---

// Player minimizzato
class MiniAudioPlayer extends StatelessWidget {
  final String titolo;
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  const MiniAudioPlayer({
    super.key,
    required this.titolo,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.onExpand,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 124,
      left: 60,
      right: 60,
      child: Card(
        color: Colors.black.withValues(alpha: 0.75),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.audiotrack, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titolo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: onTogglePlay,
              ),
              IconButton(
                icon: const Icon(
                  Icons.open_in_full,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: onExpand,
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Player espanso
class ExpandedAudioPlayer extends StatelessWidget {
  final String titolo;
  final bool isPlaying;
  final Duration duration;
  final Duration position;
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
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.only(
              top: 12,
              bottom: 12,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExpandedPlayerHeader(
                  onMinimize: onMinimize,
                  onClose: onClose,
                ),
                ExpandedPlayerTitle(titolo: titolo),
                const SizedBox(height: 16),
                const Icon(
                  Icons.audiotrack,
                  size: 64,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 16),
                AudioProgressBar(
                  duration: duration,
                  position: position,
                  onSeek: onSeek,
                ),
                const SizedBox(height: 16),
                AudioPlayPauseButton(
                  isPlaying: isPlaying,
                  onTogglePlay: onTogglePlay,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Header del player espanso
class ExpandedPlayerHeader extends StatelessWidget {
  final VoidCallback onMinimize;
  final VoidCallback onClose;

  const ExpandedPlayerHeader({
    super.key,
    required this.onMinimize,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white54,
          ),
          onPressed: onMinimize,
        ),
        IconButton(
          icon: const Icon(
            Icons.close,
            color: Colors.redAccent,
            size: 24,
          ),
          onPressed: onClose,
        ),
      ],
    );
  }
}

// Titolo dell'audio
class ExpandedPlayerTitle extends StatelessWidget {
  final String titolo;

  const ExpandedPlayerTitle({super.key, required this.titolo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        titolo,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// Barra di scorrimento e minutaggio
class AudioProgressBar extends StatelessWidget {
  final Duration duration;
  final Duration position;
  final ValueChanged<double> onSeek;

  const AudioProgressBar({
    super.key,
    required this.duration,
    required this.position,
    required this.onSeek,
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
              style: const TextStyle(color: Colors.white54),
            ),
            Text(
              _formatDuration(duration),
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ],
    );
  }
}

// Pulsante Play/Pausa
class AudioPlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTogglePlay;

  const AudioPlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.blueAccent,
      child: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 32,
        ),
        onPressed: onTogglePlay,
      ),
    );
  }
}
