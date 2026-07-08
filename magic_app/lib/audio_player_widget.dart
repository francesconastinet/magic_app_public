import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'models.dart';

class AudioPlayerWidget extends StatefulWidget {
  final MediaItem media;

  const AudioPlayerWidget({
    super.key,
    required this.media,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _stato = PlayerState.stopped;
  Duration _durata = Duration.zero;
  Duration _posizione = Duration.zero;

  @override
  void initState() {
    super.initState();

    // Ascolta i cambiamenti di stato del player
    _player.onPlayerStateChanged.listen((stato) {
      if (mounted) setState(() => _stato = stato);
    });

    // Ascolta la durata totale della traccia
    _player.onDurationChanged.listen((durata) {
      if (mounted) setState(() => _durata = durata);
    });

    // Ascolta la posizione corrente
    _player.onPositionChanged.listen((posizione) {
      if (mounted) setState(() => _posizione = posizione);
    });
  }

  @override
  void dispose() {
    // Rilascia le risorse del player
    _player.dispose();
    super.dispose();
  }

  // Formatta Duration in mm:ss
  String _formatDurata(Duration d) {
    final minuti = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secondi = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minuti:$secondi';
  }

  Future<void> _playPause() async {
    if (_stato == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.media.url));
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() => _posizione = Duration.zero);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPlaying = _stato == PlayerState.playing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titolo traccia
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Colors.purple.withValues(alpha: 0.15),
                  child: const Icon(Icons.headphones,
                      color: Colors.purple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.media.titolo,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      if (widget.media.descrizione.isNotEmpty)
                        Text(widget.media.descrizione,
                            style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Barra di avanzamento
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: _posizione.inSeconds.toDouble().clamp(
                    0,
                    _durata.inSeconds > 0
                        ? _durata.inSeconds.toDouble()
                        : 1),
                max: _durata.inSeconds > 0
                    ? _durata.inSeconds.toDouble()
                    : 1,
                onChanged: (valore) async {
                  await _player
                      .seek(Duration(seconds: valore.toInt()));
                },
                activeColor: Colors.purple,
              ),
            ),

            // Tempi e controlli
            Row(
              children: [
                // Tempo corrente
                Text(_formatDurata(_posizione),
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
                const Spacer(),
                // Bottone Stop
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _stato == PlayerState.stopped
                      ? null
                      : _stop,
                  color: colorScheme.onSurfaceVariant,
                  iconSize: 20,
                ),
                // Bottone Play/Pause
                FloatingActionButton.small(
                  heroTag: widget.media.url,
                  onPressed: _playPause,
                  backgroundColor: Colors.purple,
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                // Durata totale
                Text(_formatDurata(_durata),
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}