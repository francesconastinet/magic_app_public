import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/app_config.dart'; // NUOVO — serve per il packageId del pacchetto scaricato
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
  void Function()? onMostraOverlayAnimation;
  void Function()? onNascondiOverlayAnimation;

  ARViewModel({required this._repository})
    : _recognitionService = RecognitionService() {
    // MODIFICATO — prima prova il modello scaricato dal backend, poi quello negli assets
    // (riga originale: _recognitionService.inizializza();)
    _inizializzaRiconoscimento();
  }

  // NUOVO — prova a caricare il modello dalla cartella "modello" del pacchetto
  // scaricato (magic_packages/<packageId>/modello/). Se non c'e' ancora (primo
  // avvio, sync non fatta, VPN spenta) ripiega sul modello negli assets
  Future<void> _inizializzaRiconoscimento() async {
    try {
      await _recognitionService.inizializzaDaFile(AppConfig.packageId);
      debugPrint('[AR] Modello caricato dal pacchetto scaricato');
    } catch (e) {
      debugPrint(
        '[AR] Modello del pacchetto non disponibile ($e) — uso quello negli assets',
      );
      await _recognitionService.inizializza();
    }
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
                status: '',
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
        // NUOVO — log di cosa vede il modello, utile per i test
        debugPrint(
          '[AR] Riconosciuto: $risultato${risultato.isNone ? ' (None)' : ''}',
        );
        if (risultato.isAffidabile) {
          // MODIFICATO — cerca prima il libro: se non e' nel catalogo non
          // ferma la scansione e non apre nessun overlay
          // (righe originali:
          //   fermaScansioneAutomatica();
          //   operaRiconosciuta = _repository.trovaPerNome(risultato.nomeOpera);
          //   mostraOverlay();)
          final libro = _repository.trovaPerNome(risultato.nomeOpera);
          if (libro == null) {
            debugPrint(
              '[AR] "${risultato.nomeOpera}" non e\' presente nel catalogo',
            );
          } else {
            fermaScansioneAutomatica();
            operaRiconosciuta = libro;
            mostraOverlay();
          }
        } else if (risultato.isNone) {
          // NUOVO — classe None: non e' un libro del catalogo, nessun avviso
        } else {
          onShowWarning?.call("Confidenza bassa. Avvicinati all'opera.");
        }
      }
    } catch (e) {
      debugPrint('Errore Riconoscimento ML: $e');
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