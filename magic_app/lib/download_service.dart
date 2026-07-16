import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class DownloadService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );

  // Scarica il ZIP e restituisce il percorso del file
  Future<String> scaricaZip({
    required String url,
    required String nomeFile,
    void Function(int received, int total)? onProgress,
  }) async {
    final temp = await getTemporaryDirectory();
    final percorso = '${temp.path}/$nomeFile';

    await _dio.download(
      url,
      percorso,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress?.call(received, total);
          final percent = (received / total * 100).toStringAsFixed(0);
          debugPrint('Download: $percent%');
        }
      },
    );

    return percorso;
  }

  // Legge il file ZIP scaricato come bytes
  Future<List<int>> leggiZip(String percorso) async {
    final file = File(percorso);
    return await file.readAsBytes();
  }

  // Elimina il file ZIP temporaneo dopo l'estrazione
  Future<void> eliminaTemp(String percorso) async {
    final file = File(percorso);
    if (await file.exists()) await file.delete();
  }
}
