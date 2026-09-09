import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/catalogue_repository.dart';
import '../data/models.dart';
import '../services/recognition_service.dart';

class ARViewModel extends ChangeNotifier {
  final CatalogueRepository _repository;
  final RecognitionService _recognitionService;

  // --- STATO ---
  CameraController? camController;
  bool cameraReady = false;
  bool elaborazione = false;
  String? errore;
  bool overlayVisibile = false;
  BookModel? operaRiconosciuta;

  MediaItem? audioInEsecuzione;
  bool audioMinimizzato = false;

  bool _isAutoScanning = false;
  Timer? _scanTimer;

  // --- EVENTI UI ---
  void Function(String)? onShowWarning;
  void Function(String)? onShowError;
  void Function()? onMostraOverlayAnimation;
  void Function()? onNascondiOverlayAnimation;

  ARViewModel({required this._repository})
    : _recognitionService = RecognitionService() {
    _recognitionService.inizializza();
  }

  @override
  void dispose() {
    fermaScansioneAutomatica();
    camController?.dispose();
    _recognitionService.dispose();
    super.dispose();
  }

  // --- LOGICA ---

  Future<void> inizializzaCamera({String? nomeOperaIniziale}) async {
    final permesso = await Permission.camera.request();
    if (!permesso.isGranted) {
      errore = 'Permesso fotocamera negato';
      notifyListeners();
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      errore = 'Nessuna fotocamera trovata';
      notifyListeners();
      return;
    }

    camController = CameraController(cameras.first, ResolutionPreset.medium);
    await camController!.initialize();

    cameraReady = true;
    notifyListeners();

    if (nomeOperaIniziale != null) {
      operaRiconosciuta = _repository.libri.firstWhere(
        (o) => o.titolo == nomeOperaIniziale,
        orElse: () => _repository.libri.isNotEmpty
            ? _repository.libri.first
            : BookModel(
                id: 'err',
                titolo: 'Errore',
                autore: '',
                anno: '',
                multimedia: [],
              ),
      );
      mostraOverlay();
    } else {
      avviaScansioneAutomatica();
    }
  }

  void avviaScansioneAutomatica() {
    if (_isAutoScanning) return;
    _isAutoScanning = true;

    _scanTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (cameraReady && !overlayVisibile && !elaborazione) {
        riconosci();
      }
    });
  }

  void fermaScansioneAutomatica() {
    _isAutoScanning = false;
    _scanTimer?.cancel();
  }

  Future<void> riconosci() async {
    if (camController == null ||
        !camController!.value.isInitialized ||
        camController!.value.isTakingPicture) {
      return;
    }

    elaborazione = true;
    notifyListeners();

    try {
      final foto = await camController!.takePicture();
      final bytes = await foto.readAsBytes();
      final risultato = await _recognitionService.riconosci(bytes);

      if (!overlayVisibile && risultato != null) {
        if (risultato.isAffidabile) {
          fermaScansioneAutomatica();
          operaRiconosciuta = _repository.trovaPerNome(risultato.nomeOpera);
          mostraOverlay();
        } else {
          onShowWarning?.call("Confidenza bassa. Avvicinati all'opera.");
        }
      }
    } catch (e) {
      debugPrint('Errore Riconoscimento ML: $e');
      if (!overlayVisibile) {
        onShowError?.call("Errore della fotocamera. Riprovo...");
      }
    } finally {
      elaborazione = false;
      notifyListeners();
    }
  }

  void mostraOverlay() {
    overlayVisibile = true;
    audioInEsecuzione = null;
    notifyListeners();
    onMostraOverlayAnimation?.call();
  }

  void nascondiOverlay() {
    onNascondiOverlayAnimation?.call();
  }

  void onAnimazioneChiusuraCompletata() {
    overlayVisibile = false;
    audioInEsecuzione = null;
    notifyListeners();
    avviaScansioneAutomatica();
  }

  void simulaRiconoscimento(BookModel book) {
    operaRiconosciuta = book;
    mostraOverlay();
  }

  void impostaAudio(MediaItem? audio, {bool minimizzato = false}) {
    audioInEsecuzione = audio;
    audioMinimizzato = minimizzato;
    notifyListeners();
  }
}
