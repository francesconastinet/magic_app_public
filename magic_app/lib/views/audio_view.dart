import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../viewmodels/audio_viewmodel.dart';

// ==========================================
// SCHERMATA
// ==========================================

class AudioView extends StatefulWidget {
  final String titolo;
  final String audioPath;
  final bool isMinimized;
  final VoidCallback onMinimizeToggle;
  final VoidCallback onClose;

  const AudioView({
    super.key,
    required this.titolo,
    required this.audioPath,
    required this.isMinimized,
    required this.onMinimizeToggle,
    required this.onClose,
  });

  @override
  State<AudioView> createState() => _AudioViewState();
}

class _AudioViewState extends State<AudioView> {
  late AudioViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AudioViewModel(storageService: context.read<StorageService>());
    _viewModel.inizializzaAudio(widget.audioPath);
  }

  @override
  void didUpdateWidget(covariant AudioView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioPath != widget.audioPath) {
      _viewModel.stopAndReset().then((_) {
        _viewModel.inizializzaAudio(widget.audioPath);
      });
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMinimized) {
      return const SizedBox.shrink();
    }

    final layout = AudioLayout(context);

    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<AudioViewModel>(
        builder: (context, vm, child) {
          return ExpandedAudioPlayer(
            titolo: widget.titolo,
            isPlaying: vm.isPlaying,
            durationNotifier: vm.durationNotifier,
            positionNotifier: vm.positionNotifier,
            layout: layout,
            onTogglePlay: vm.togglePlayPause,
            onSeek: vm.seek,
            onMinimize: widget.onMinimizeToggle,
            onClose: widget.onClose,
          );
        },
      ),
    );
  }
}

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
// WIDGET
// ==========================================

// --- PLAYER ---
class ExpandedAudioPlayer extends StatelessWidget {
  final String titolo;
  final bool isPlaying;
  final ValueNotifier<Duration> durationNotifier;
  final ValueNotifier<Duration> positionNotifier;
  final AudioLayout layout;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onMinimize;
  final VoidCallback onClose;

  const ExpandedAudioPlayer({
    super.key,
    required this.titolo,
    required this.isPlaying,
    required this.durationNotifier,
    required this.positionNotifier,
    required this.layout,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onMinimize,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black54,
          child: SafeArea(
            minimum: EdgeInsets.symmetric(vertical: layout.borderRadius),
            child: Center(
              child: GestureDetector(
                onTap: () {},
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
                            durationNotifier: durationNotifier,
                            positionNotifier: positionNotifier,
                            layout: layout,
                            onSeek: onSeek,
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
            color: Colors.white,
            size: layout.headerIconSize,
          ),
          onPressed: onMinimize,
        ),

        IconButton(
          icon: Icon(
            Icons.close,
            color: Colors.white,
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
  final ValueNotifier<Duration> durationNotifier;
  final ValueNotifier<Duration> positionNotifier;
  final AudioLayout layout;
  final ValueChanged<Duration> onSeek;

  const AudioProgressBar({
    super.key,
    required this.durationNotifier,
    required this.positionNotifier,
    required this.layout,
    required this.onSeek,
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
                  onChanged: (valore) {
                    onSeek(Duration(seconds: valore.toInt()));
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
