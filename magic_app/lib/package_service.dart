import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package_storage.dart';
import 'package:flutter/foundation.dart';
import 'download_service.dart';
import 'update_service.dart';
import 'models.dart';

class PackageService {
  final PackageStorage _storage = PackageStorage();
  final UpdateService _updateService = UpdateService();

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
    String? versione,
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

    // 5. Salva la versione installata su disco
    if (versione != null) {
      await _updateService.salvaVersioneInstallata(packageId, versione);
      debugPrint('Versione $versione registrata per $packageId');
    }
  }

  // Legge info.json di un manoscritto dal disco (vecchia struttura)
  Future<Map<String, dynamic>?> leggiInfoManoscritto(
      String packageId, String collectionId, String msId) async {
    final path =
        'collections/$collectionId/manuscripts/$msId/info.json';
    return await _storage.leggiJson(packageId, path);
  }

  // Legge collection.json dal disco (vecchia struttura)
  Future<Map<String, dynamic>?> leggiCollection(
      String packageId, String collectionId) async {
    return await _storage.leggiJson(
        packageId, 'collections/$collectionId/collection.json');
  }

  // Verifica se il pacchetto e' gia' estratto
  Future<bool> isPacchettoInstallato(String packageId) async {
    return await _storage.pacchettoPresenteSync(packageId);
  }

  // Controlla se c'e' un aggiornamento disponibile
  Future<bool> isAggiornamentoDisponibile(
      String packageId, String versioneManifest) async {
    return await _updateService.isAggiornamentoDisponibile(
        packageId, versioneManifest);
  }

  // Lista file nel ZIP (per test)
  Future<List<String>> listaFile() async {
    final archive = await _caricaArchivio();
    return archive.files
        .where((f) => f.isFile)
        .map((f) => f.name)
        .toList();
  }

  // --- NUOVA STRUTTURA PACCHETTO ---

  // Legge books.json — lista piatta di tutti i libri
  Future<List<BookModel>> leggiLibri(String packageId) async {
    final contenuto = await _storage.leggiFile(packageId, 'books.json');
    if (contenuto == null) return [];
    final lista = jsonDecode(contenuto) as List;
    return lista.map((b) => BookModel.fromJson(b)).toList();
  }

  // Legge un singolo libro da books.json per id
  Future<BookModel?> leggiLibro(String packageId, String bookId) async {
    final libri = await leggiLibri(packageId);
    try {
      return libri.firstWhere((b) => b.id == bookId);
    } catch (_) {
      return null;
    }
  }

  // Legge collections.json — raggruppamento libri in percorsi
  Future<List<CollectionV2Model>> leggiCollezioniV2(
      String packageId) async {
    final contenuto =
        await _storage.leggiFile(packageId, 'collections.json');
    if (contenuto == null) return [];
    final lista = jsonDecode(contenuto) as List;
    return lista.map((c) => CollectionV2Model.fromJson(c)).toList();
  }

  // Legge i libri di una specifica collezione
  Future<List<BookModel>> leggiLibriDiCollezione(
      String packageId, String collectionId) async {
    final collezioni = await leggiCollezioniV2(packageId);
    final collezione = collezioni.where((c) => c.id == collectionId);
    if (collezione.isEmpty) return [];
    final bookIds = collezione.first.bookIds;
    final tuttiLibri = await leggiLibri(packageId);
    // Restituisce i libri nell'ordine della collezione
    return bookIds
        .map((id) => tuttiLibri.where((b) => b.id == id))
        .where((list) => list.isNotEmpty)
        .map((list) => list.first)
        .toList();
  }
}