import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package_storage.dart';
import 'package:flutter/foundation.dart';
import 'download_service.dart';

class PackageService {
  final PackageStorage _storage = PackageStorage();

  // Carica e decodifica il ZIP dagli asset
  Future<Archive> _caricaArchivio() async {
    final byteData = await rootBundle.load('assets/magic_package_v1.zip');
    final bytes = byteData.buffer.asUint8List();
    return ZipDecoder().decodeBytes(bytes);
  }

  // Estrae il ZIP su disco
  Future<void> estraiPacchetto(String packageId) async {
    final archive = await _caricaArchivio();
    int fileEstratti = 0;

    for (final file in archive.files) {
      if (!file.isFile) continue;

      // Rimuove il prefisso della cartella radice del ZIP
      // es. "magic_package/collections/..." → "collections/..."
      final parts = file.name.split('/');
      if (parts.length < 2) continue;
      final relativePath = parts.sublist(1).join('/');
      if (relativePath.isEmpty) continue;

      await _storage.salvaFile(
          packageId, relativePath, file.content as List<int>);
      fileEstratti++;
    }

    debugPrint('Estratti $fileEstratti file per pacchetto $packageId');
  }

  // Scarica ed estrae il pacchetto da URL
  Future<void> scaricaEEstrai({
    required String url,
    required String packageId,
    void Function(int received, int total)? onProgress,
  }) async {
    final downloader = DownloadService();

    // 1. Scarica il ZIP nella cartella temporanea
    final percorsoZip = await downloader.scaricaZip(
      url: url,
      nomeFile: '$packageId.zip',
      onProgress: onProgress,
    );

    // 2. Legge i bytes del ZIP
    final bytes = await downloader.leggiZip(percorsoZip);

    // 3. Estrae i file su disco
    final archive = ZipDecoder().decodeBytes(bytes);
    int fileEstratti = 0;

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final parts = file.name.split('/');
      if (parts.length < 2) continue;
      final relativePath = parts.sublist(1).join('/');
      if (relativePath.isEmpty) continue;
      await _storage.salvaFile(
          packageId, relativePath, file.content as List<int>);
      fileEstratti++;
    }

    // 4. Elimina il file temporaneo
    await downloader.eliminaTemp(percorsoZip);
    debugPrint('Installati $fileEstratti file per $packageId');
  }

  // Legge info.json di un manoscritto dal disco
  Future<Map<String, dynamic>?> leggiInfoManoscritto(
      String packageId, String collectionId, String msId) async {
    final path =
        'collections/$collectionId/manuscripts/$msId/info.json';
    return await _storage.leggiJson(packageId, path);
  }

  // Legge collection.json dal disco
  Future<Map<String, dynamic>?> leggiCollection(
      String packageId, String collectionId) async {
    return await _storage.leggiJson(
        packageId, 'collections/$collectionId/collection.json');
  }

  // Verifica se il pacchetto e' gia' estratto
  Future<bool> isPacchettoInstallato(String packageId) async {
    return await _storage.pacchettoPresenteSync(packageId);
  }

  // Lista file nel ZIP (per test)
  Future<List<String>> listaFile() async {
    final archive = await _caricaArchivio();
    return archive.files
        .where((f) => f.isFile)
        .map((f) => f.name)
        .toList();
  }
}