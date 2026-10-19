import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// Servizio di TEST per misurare il modello TFLite (classificatore a classi)
// con la stessa logica del benchmark del pixel matching: per ogni foto
// restituisce libro scelto, confidenza, primi tre candidati e tempi.
// Non tocca RecognitionService: usa un modello e dei labels di test messi in
// assets/test_model_unquant.tflite e assets/test_labels.txt, così non si
// sovrascrive il modello dell'app.
class TfliteBenchmark {
  static const String _assetModello = 'assets/test_model_unquant.tflite';
  static const String _assetLabels = 'assets/test_labels.txt';

  // Stessa soglia di RecognitionService.isAffidabile
  static const double sogliaAffidabile = 0.7;

  // Dimensione di ingresso del modello (MobileNetV2)
  static const int _dimensione = 224;

  Interpreter? _interprete;
  List<String> _labels = [];
  int _numUscite = 0;
  int _inferenzeFatte = 0;

  bool get pronto => _interprete != null;
  int get numUscite => _numUscite;
  int get numLabels => _labels.length;

  // Come RecognitionService._pulisciLabel: toglie l'indice iniziale e
  // sostituisce gli underscore con spazi
  String _pulisciLabel(String riga) {
    final senzaIndice = riga.replaceFirst(RegExp(r'^\d+\s+'), '');
    return senzaIndice.replaceAll('_', ' ').trim();
  }

  Future<void> carica() async {
    final labelsData = await rootBundle.loadString(_assetLabels);
    _labels = labelsData
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => _pulisciLabel(l))
        .toList();

    _interprete = await Interpreter.fromAsset(_assetModello);

    // Il numero di uscite si legge dal modello, non dai labels, così un
    // labels.txt sbagliato non rompe la lettura dei risultati
    final forma = _interprete!.getOutputTensor(0).shape;
    _numUscite = forma.last;
    _inferenzeFatte = 0;

    debugPrint(
      '[ML] modello caricato: forma uscita $forma, labels ${_labels.length}',
    );
    if (_numUscite != _labels.length) {
      debugPrint(
        '[ML] ATTENZIONE: il modello ha $_numUscite uscite ma labels.txt ha '
        '${_labels.length} righe',
      );
    }
  }

  // Prepara l'immagine e la passa al modello.
  // - normalizzaMenoUnoUno: true = (x / 127.5) - 1, come il training di
  //   Rosario; false = x / 255, come fa oggi RecognitionService
  // - interpolazioneLineare: true = ridimensionamento lineare (come il
  //   training); false = nearest, che è il default di img.copyResize
  // - applicaOrientamentoExif: true = ruota la foto secondo l'orientamento
  //   EXIF prima del ridimensionamento
  Future<Map<String, dynamic>> riconosci(
    Uint8List bytes, {
    bool normalizzaMenoUnoUno = true,
    bool interpolazioneLineare = true,
    bool applicaOrientamentoExif = true,
  }) async {
    if (_interprete == null) {
      throw Exception('Modello non caricato');
    }

    final swPreparazione = Stopwatch()..start();

    var immagine = img.decodeImage(bytes);
    if (immagine == null) {
      throw Exception('Immagine non decodificabile');
    }
    final larghezzaOriginale = immagine.width;
    final altezzaOriginale = immagine.height;

    if (applicaOrientamentoExif) {
      immagine = img.bakeOrientation(immagine);
    }

    final ridimensionata = img.copyResize(
      immagine,
      width: _dimensione,
      height: _dimensione,
      interpolation: interpolazioneLineare
          ? img.Interpolation.linear
          : img.Interpolation.nearest,
    );

    final input = List.generate(
      1,
      (_) => List.generate(
        _dimensione,
        (y) => List.generate(_dimensione, (x) {
          final pixel = ridimensionata.getPixel(x, y);
          final valori = [pixel.r, pixel.g, pixel.b];
          return List.generate(
            3,
            (c) => normalizzaMenoUnoUno
                ? valori[c] / 127.5 - 1.0
                : valori[c] / 255.0,
          );
        }),
      ),
    );
    swPreparazione.stop();

    final output = List.filled(_numUscite, 0.0).reshape([1, _numUscite]);

    final swInferenza = Stopwatch()..start();
    _interprete!.run(input, output);
    swInferenza.stop();

    final primaInferenza = _inferenzeFatte == 0;
    _inferenzeFatte++;

    final scores = List<double>.from(output[0] as List);

    // Indici ordinati per confidenza decrescente
    final ordine = List<int>.generate(scores.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));

    String nomeLabel(int i) => i < _labels.length ? _labels[i] : 'classe $i';

    final classifica = <Map<String, dynamic>>[];
    for (int k = 0; k < ordine.length && k < 3; k++) {
      classifica.add({
        'indice': ordine[k],
        'nome': nomeLabel(ordine[k]),
        'score': scores[ordine[k]],
      });
    }

    final migliore = classifica.first;
    final nomeMigliore = (migliore['nome'] as String).toLowerCase();
    // La classe "None" (o "altro") significa "non è un libro del catalogo"
    final isNone = nomeMigliore == 'none' || nomeMigliore == 'altro';

    return {
      'larghezza': larghezzaOriginale,
      'altezza': altezzaOriginale,
      'tempoPreparazioneMs': swPreparazione.elapsedMilliseconds,
      'tempoInferenzaMs': swInferenza.elapsedMilliseconds,
      'primaInferenza': primaInferenza,
      'classifica': classifica,
      'nomeMigliore': migliore['nome'] as String,
      'scoreMigliore': migliore['score'] as double,
      'affidabile': (migliore['score'] as double) >= sogliaAffidabile,
      'isNone': isNone,
    };
  }

  void dispose() {
    _interprete?.close();
    _interprete = null;
  }
}