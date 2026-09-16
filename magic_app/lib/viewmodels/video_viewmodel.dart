import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../core/app_config.dart';
import '../services/storage_service.dart';

class VideoViewModel extends ChangeNotifier {
  // --- DIPENDENZE ---
  final StorageService _storageService;

  // --- STATO ---
  VideoPlayerController? controller;
  bool isInitialized = false;
  bool hasError = false;
  bool mostraControlli = true;
  Timer? _timerNascondiControlli;

  VideoViewModel({required this._storageService});

  @override
  void dispose() {
    _timerNascondiControlli?.cancel();
    controller?.dispose();
    super.dispose();
  }

  // --- LOGICA ---

  Future<void> inizializzaVideo(String videoPath) async {
    try {
      if (videoPath.startsWith('assets/')) {
        controller = VideoPlayerController.asset(videoPath);
      } else {
        final basePath = await _storageService.percorsoPacchetto(
          AppConfig.packageId,
        );
        final percorsoAssoluto = '$basePath/$videoPath';
        controller = VideoPlayerController.file(File(percorsoAssoluto));
      }

      await controller!.initialize();
      controller!.addListener(notifyListeners);

      isInitialized = true;
      notifyListeners();

      controller!.play();
      avviaTimerNascondiControlli();
    } catch (e) {
      debugPrint('Errore caricamento video: $e');
      hasError = true;
      notifyListeners();
    }
  }

  Future<void> salta(int secondi) async {
    if (controller == null || !controller!.value.isInitialized) return;
    final posizioneCorrente = await controller!.position;
    if (posizioneCorrente != null) {
      final nuovaPosizione = posizioneCorrente + Duration(seconds: secondi);
      await controller!.seekTo(nuovaPosizione);
    }
  }

  void toggleControlli() {
    mostraControlli = !mostraControlli;
    notifyListeners();

    if (mostraControlli) {
      avviaTimerNascondiControlli();
    } else {
      _timerNascondiControlli?.cancel();
    }
  }

  void avviaTimerNascondiControlli() {
    _timerNascondiControlli?.cancel();
    if (controller != null && !controller!.value.isPlaying) return;

    _timerNascondiControlli = Timer(const Duration(seconds: 2), () {
      mostraControlli = false;
      notifyListeners();
    });
  }

  void fermaTimerControlli() {
    _timerNascondiControlli?.cancel();
  }

  void togglePlay() {
    if (controller == null) return;

    if (controller!.value.isPlaying) {
      controller!.pause();
      fermaTimerControlli();
    } else {
      controller!.play();
      avviaTimerNascondiControlli();
    }
    notifyListeners();
  }
}
