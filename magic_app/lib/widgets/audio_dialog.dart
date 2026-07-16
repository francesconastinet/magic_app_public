import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../package_storage.dart';

class AudioDialog extends StatefulWidget {
  final String titolo;
  final String audioPath;

  const AudioDialog({
    super.key,
    required this.titolo,
    required this.audioPath,
  });

  @override
  State<AudioDialog> createState() => _AudioDialogState();
}

class _AudioDialogState extends State<AudioDialog> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _inizializzaAudio();

    // Ascolta i cambiamenti di stato (Play/Pausa)
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    // Ascolta la durata totale del file
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    // Ascolta la posizione corrente (per far muovere lo slider)
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
  }

  Future<void> _inizializzaAudio() async {
    try {
      // CASO 1: File negli asset (Modalità Test)
      // TODO: rimuovere quando il client sarà collegato al backend
      if (widget.audioPath.startsWith('assets/')) {
        final assetPath = widget.audioPath.replaceFirst('assets/', '');
        await _audioPlayer.setSource(AssetSource(assetPath));
      }
      // CASO 2: File nel file system (Scaricato dallo ZIP)
      else {
        final storageService = context.read<PackageStorage>();
        final basePath = await storageService.percorsoPacchetto(AppConfig.packageId);
        final percorsoAssoluto = '$basePath/${widget.audioPath}';

        await _audioPlayer.setSourceDeviceFile(percorsoAssoluto);
      }
    } catch (e) {
      debugPrint('Errore caricamento audio: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.titolo, style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.audiotrack, size: 64, color: Colors.blueAccent),
          const SizedBox(height: 16),
          Slider(
            activeColor: Colors.blueAccent,
            inactiveColor: Colors.white24,
            min: 0,
            max: _duration.inSeconds.toDouble(),
            value: _position.inSeconds.toDouble().clamp(
                0,
                _duration.inSeconds.toDouble()),
            onChanged: (value) async {
              final position = Duration(seconds: value.toInt());
              await _audioPlayer.seek(position);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  _formatDuration(_position),
                  style: const TextStyle(color: Colors.white54)),
              Text(
                  _formatDuration(_duration),
                  style: const TextStyle(color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.blueAccent,
            child: IconButton(
              icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white, size: 32),
              onPressed: () {
                if (_isPlaying) {
                  _audioPlayer.pause();
                } else {
                  _audioPlayer.resume();
                }
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}