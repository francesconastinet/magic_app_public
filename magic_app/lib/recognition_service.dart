import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class RisultatoRiconoscimento {
  final String nomeOpera;
  final double confidenza;

  RisultatoRiconoscimento({
    required this.nomeOpera,
    required this.confidenza,
  });

  bool get isAffidabile => confidenza >= 0.7;

  @override
  String toString() =>
      '$nomeOpera (${(confidenza * 100).toStringAsFixed(1)}%)';
}

class RecognitionService {
  Interpreter? _interprete;
  List<String> _labels = [];
  bool _pronto = false;

  bool get pronto => _pronto;

  // Carica modello dagli asset (modalita' statica)
  Future<void> inizializza() async {
    final labelsData =
        await rootBundle.loadString('assets/labels.txt');
    _labels = labelsData
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    _interprete =
        await Interpreter.fromAsset('assets/model_unquant.tflite');
    _pronto = true;
  }

  // Carica modello dal pacchetto scaricato (modalita' dinamica)
  Future<void> inizializzaDaFile(
      String packageId, String collectionId) async {
    final docs = await getApplicationDocumentsDirectory();
    final base = '${docs.path}/magic_packages/$packageId'
        '/collections/$collectionId';

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
        .toList();

    // Carica modello dal disco
    final modelFile = File('$base/model_unquant.tflite');
    if (!await modelFile.exists()) {
      throw Exception('model_unquant.tflite non trovato in $base');
    }
    _interprete = await Interpreter.fromFile(modelFile);
    _pronto = true;
  }

  Future<RisultatoRiconoscimento?> riconosci(List<int> bytes) async {
    if (!_pronto || _interprete == null) return null;

    final inputImage = _preparaImmagine(bytes);
    final output =
        List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);

    _interprete!.run(inputImage, output);

    final scores = output[0] as List<double>;
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
    final immagine = img.decodeImage(Uint8List.fromList(bytes))!;
    final ridimensionata =
        img.copyResize(immagine, width: 224, height: 224);
    return List.generate(
        1,
        (_) => List.generate(
            224,
            (y) => List.generate(
                224,
                (x) => List.generate(3, (c) {
                      final pixel = ridimensionata.getPixel(x, y);
                      final valori = [pixel.r, pixel.g, pixel.b];
                      return valori[c] / 255.0;
                    }))));
  }

  void dispose() {
    _interprete?.close();
    _pronto = false;
  }
}