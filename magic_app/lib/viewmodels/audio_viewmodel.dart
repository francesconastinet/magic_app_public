import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/app_config.dart';
import '../services/storage_service.dart';

class AudioViewModel extends ChangeNotifier {
  final StorageService _storageService;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isPlaying = false;
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);

  StreamSubscription? _stateSub;
  StreamSubscription? _durSub;
  StreamSubscription? _posSub;
  StreamSubscription? _completeSub;

  AudioViewModel({required this._storageService}) {
    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    _durSub = _audioPlayer.onDurationChanged.listen((duration) {
      durationNotifier.value = duration;
    });

    _posSub = _audioPlayer.onPositionChanged.listen((position) {
      positionNotifier.value = position;
    });

    _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
      isPlaying = false;
      positionNotifier.value = Duration.zero;
      _audioPlayer.seek(Duration.zero);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _durSub?.cancel();
    _posSub?.cancel();
    _completeSub?.cancel();
    durationNotifier.dispose();
    positionNotifier.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- LOGICA ---
  Future<void> inizializzaAudio(String audioPath) async {
    try {
      if (audioPath.startsWith('assets/')) {
        final assetPath = audioPath.replaceFirst('assets/', '');
        await _audioPlayer.setSource(AssetSource(assetPath));
      } else {
        final basePath = await _storageService.percorsoPacchetto(
          AppConfig.packageId,
        );
        final percorsoAssoluto = '$basePath/$audioPath';
        await _audioPlayer.setSourceDeviceFile(percorsoAssoluto);
      }
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Errore caricamento audio: $e');
    }
  }

  void togglePlayPause() {
    if (isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.resume();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> stopAndReset() async {
    await _audioPlayer.stop();
    isPlaying = false;
    durationNotifier.value = Duration.zero;
    positionNotifier.value = Duration.zero;
    notifyListeners();
  }
}
