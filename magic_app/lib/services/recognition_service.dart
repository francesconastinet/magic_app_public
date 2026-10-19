import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint; // NUOVO — serve per il log dei primi 3 risultati
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class RisultatoRiconoscimento {
  final String nomeOpera;
  final double confidenza;

  RisultatoRiconoscimento({required this.nomeOpera, required this.confidenza});

  // NUOVO — true se il modello ha scelto la classe "None" (foto non riconducibile
  // a nessun libro del catalogo). La label viene da labels.txt (dopo _pulisciLabel)
  bool get isNone =>
      nomeOpera.toLowerCase() == 'none' || nomeOpera.toLowerCase() == 'altro';

  // MODIFICATO — se la classe vincente e' None il risultato non e' mai affidabile
  // (riga originale: bool get isAffidabile => confidenza >= 0.7;)
  bool get isAffidabile => !isNone && confidenza >= 0.7;

  @override
  String toString() => '$nomeOpera (${(confidenza * 100).toStringAsFixed(1)}%)';
}

class RecognitionService {
  Interpreter? _interprete;
  List<String> _labels = [];
  bool _pronto = false;

  bool get pronto => _pronto;

  // Pulisce una riga del labels.txt rimuovendo l'indice numerico iniziale
  // e sostituendo underscore con spazi
  // es. "0 Divina_commedia" -> "Divina commedia"
  // es. "Divina_commedia" (senza indice) -> "Divina commedia"
  String _pulisciLabel(String riga) {
    // Rimuove un eventuale prefisso numerico seguito da spazio (es. "0 ", "12 ")
    final senzaIndice = riga.replaceFirst(RegExp(r'^\d+\s+'), '');
    // Sostituisce underscore con spazi per un confronto piu' naturale
    return senzaIndice.replaceAll('_', ' ').trim();
  }

  // Carica modello dagli asset (modalita' statica)
  Future<void> inizializza() async {
    final labelsData = await rootBundle.loadString('assets/labels.txt');
    _labels = labelsData
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => _pulisciLabel(l))
        .toList();

    _interprete = await Interpreter.fromAsset('assets/model_unquant.tflite');
    _pronto = true;
  }

  // Carica modello dal pacchetto scaricato (modalita' dinamica)
  // MODIFICATO — il backend mette model_unquant.tflite e labels.txt nella cartella
  // "modello" alla radice dello zip, quindi il percorso e'
  // magic_packages/<packageId>/modello/ e non piu' collections/<collectionId>/
  // (firma originale: Future<void> inizializzaDaFile(String packageId, String collectionId) async {)
  Future<void> inizializzaDaFile(
    String packageId, {
    String cartellaModello = 'modello',
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    // (percorso originale:
    //   '${docs.path}/magic_packages/$packageId'
    //   '/collections/$collectionId')
    final base = '${docs.path}/magic_packages/$packageId/$cartellaModello';

    // Carica labels dal disco
    final labelsFile = File('$base/labels.txt');
    if (!await labelsFile.exists()) {
      throw Exception('labels.txt non trovato in $base');
    }
    final labelsData = await labelsFile.readAsString();
    _labels = labelsData
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => _pulisciLabel(l))
        .toList();

    // Carica modello dal disco
    final modelFile = File('$base/model_unquant.tflite');
    if (!await modelFile.exists()) {
      throw Exception('model_unquant.tflite non trovato in $base');
    }
    _interprete = Interpreter.fromFile(modelFile);
    _pronto = true;
  }

  Future<RisultatoRiconoscimento?> riconosci(List<int> bytes) async {
    if (!_pronto || _interprete == null) return null;

    final inputImage = _preparaImmagine(bytes);
    final output = List.filled(
      1 * _labels.length,
      0.0,
    ).reshape([1, _labels.length]);

    _interprete!.run(inputImage, output);

    final scores = output[0] as List<double>;

    // NUOVO — log dei primi 3 risultati con la confidenza, utile per i test: si vede
    // se il libro giusto e' secondo o terzo e quanto e' distante dal primo
    final indiciOrdinati = List<int>.generate(scores.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    final top3 = indiciOrdinati
        .take(3)
        .map(
          (i) =>
              '${i < _labels.length ? _labels[i] : i} '
              '${(scores[i] * 100).toStringAsFixed(1)}%',
        )
        .join(' | ');
    debugPrint('[ML] Top 3: $top3');

    int bestIndex = 0;
    double bestScore = 0;
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > bestScore) {
        bestScore = scores[i];
        bestIndex = i;
      }
    }

    return RisultatoRiconoscimento(
      nomeOpera: _labels.length > bestIndex
          ? _labels[bestIndex]
          : 'Sconosciuto',
      confidenza: bestScore,
    );
  }

  List _preparaImmagine(List<int> bytes) {
    // MODIFICATO — applica l'orientamento EXIF (le foto di takePicture possono
    // essere ruotate nei metadati) per avere l'immagine dritta come nel training
    // (riga originale: final immagine = img.decodeImage(Uint8List.fromList(bytes))!;)
    final immagine = img.bakeOrientation(
      img.decodeImage(Uint8List.fromList(bytes))!,
    );
    // MODIFICATO — interpolazione lineare (come il resize del training in Keras)
    // invece di nearest (default di copyResize)
    // (riga originale: final ridimensionata = img.copyResize(immagine, width: 224, height: 224);)
    final ridimensionata = img.copyResize(
      immagine,
      width: 224,
      height: 224,
      interpolation: img.Interpolation.linear,
    );
    return List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(
          224,
          (x) => List.generate(3, (c) {
            final pixel = ridimensionata.getPixel(x, y);
            final valori = [pixel.r, pixel.g, pixel.b];
            // MODIFICATO — il training usa Rescaling(1/127.5, offset=-1), quindi
            // input in [-1, 1] e non in [0, 1]
            // (riga originale: return valori[c] / 255.0;)
            return valori[c] / 127.5 - 1.0;
          }),
        ),
      ),
    );
  }

  void dispose() {
    _interprete?.close();
    _pronto = false;
  }
}