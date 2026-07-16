import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package_storage.dart';
import 'package:flutter/foundation.dart';
import 'download_service.dart';
import 'update_service.dart';
import 'models.dart';
import 'auth_service.dart';

// Risultato della sincronizzazione automatica in background.
// Distingue "ho controllato ma non c'era nulla di nuovo" da "ho scaricato
// davvero" — serve a HomeScreen per decidere se mostrare un feedback
// all'utente o restare silenziosa.
class SyncResult {
  final bool successo;
  final bool scaricato;
  const SyncResult({required this.successo, required this.scaricato});
}

class PackageService {
  final PackageStorage _storage;
  final AuthService _authService;
  final UpdateService _updateService = UpdateService();

  // Dependency injection:
  // PackageService non crea più le sue dipendenze da solo, le riceve
  // dall'esterno (in main.dart, via context.read<...>()). Così si riusa
  // la STESSA istanza di AuthService in tutta l'app, invece di rifare
  // login ogni volta che serve un download.
  PackageService({
    required PackageStorage storage,
    required AuthService authService,
  }) : _storage = storage,
       _authService = authService;

  // Carica e decodifica il ZIP dagli asset
  Future<Archive> _caricaArchivio() async {
    final byteData = await rootBundle.load('assets/magic_package_v1.zip');
    final bytes = byteData.buffer.asUint8List();
    return ZipDecoder().decodeBytes(bytes);
  }

  // Estrae bytes ZIP su disco — gestisce sia ZIP con cartella radice che senza
  Future<void> _estraiBytes(List<int> bytes, String packageId) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    int fileEstratti = 0;

    // Verifica se il ZIP ha una cartella radice comune
    // es. "magic_package/books.json" → ha cartella radice
    // es. "books.json" → NON ha cartella radice (struttura nuova)
    final nomiFile = archive.files
        .where((f) => f.isFile)
        .map((f) => f.name)
        .toList();

    // Ha cartella radice se tutti i file hanno lo stesso primo segmento
    bool haCartellaRadice = false;
    if (nomiFile.isNotEmpty) {
      final primiSegmenti = nomiFile.map((n) => n.split('/').first).toSet();
      haCartellaRadice =
          primiSegmenti.length == 1 && nomiFile.every((n) => n.contains('/'));
    }

    debugPrint('[PKG] ZIP con cartella radice: $haCartellaRadice');
    debugPrint('[PKG] File nel ZIP: ${nomiFile.join(', ')}');

    for (final file in archive.files) {
      if (!file.isFile) continue;

      String relativePath;
      if (haCartellaRadice) {
        // Rimuove il prefisso della cartella radice del ZIP
        // es. "magic_package/books.json" → "books.json"
        final parts = file.name.split('/');
        if (parts.length < 2) continue;
        relativePath = parts.sublist(1).join('/');
      } else {
        // Nessuna cartella radice — usa il nome direttamente
        // es. "books.json" → "books.json" (struttura nuova)
        relativePath = file.name;
      }

      if (relativePath.isEmpty) continue;
      await _storage.salvaFile(
        packageId,
        relativePath,
        file.content as List<int>,
      );
      fileEstratti++;
    }
    debugPrint('[PKG] Estratti $fileEstratti file per $packageId');
  }

  // Estrae il ZIP su disco dagli asset
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
        packageId,
        relativePath,
        file.content as List<int>,
      );
      fileEstratti++;
    }

    debugPrint('Estratti $fileEstratti file per pacchetto $packageId');
  }

  // Scarica ed estrae il pacchetto da URL pubblico (GitHub Releases)
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
    await _estraiBytes(bytes, packageId);

    // 4. Elimina il file temporaneo
    await downloader.eliminaTemp(percorsoZip);
    debugPrint('Installati file per $packageId da URL');

    // 5. Salva la versione installata su disco
    if (versione != null) {
      await _updateService.salvaVersioneInstallata(packageId, versione);
      debugPrint('Versione $versione registrata per $packageId');
    }
  }

  // Scarica ed estrae il pacchetto dalle API interne (VPN)
  // MODIFICATO — usa _authService iniettato invece di crearne uno nuovo.
  // Se e' gia' loggato (token valido da una chiamata precedente), salta
  // il login e risparmia una richiesta di rete.
  Future<bool> scaricaEEstraiDaApi({
    required String packageId,
    required String versione,
    void Function(String messaggio)? onStato,
  }) async {
    if (!_authService.isLoggato) {
      onStato?.call('Autenticazione in corso...');
      final loginRiuscito = await _authService.login('utente2', 'utente2');
      if (!loginRiuscito) {
        debugPrint('[PKG] Login fallito');
        return false;
      }
    } else {
      debugPrint('[PKG] Gia\' loggato — salto il login');
    }

    // 2. Scarica il pacchetto ZIP come bytes
    onStato?.call('Download pacchetto in corso...');
    final bytes = await _authService.scaricaPacchetto();

    if (bytes == null || bytes.isEmpty) {
      debugPrint('[PKG] Pacchetto vuoto o errore download');
      return false;
    }

    // 3. Estrae i file su disco con gestione errori dettagliata
    onStato?.call('Estrazione in corso...');
    try {
      await _estraiBytes(bytes, packageId);
    } catch (e, stack) {
      debugPrint('[PKG] ERRORE ESTRAZIONE: $e');
      debugPrint('[PKG] STACK: $stack');
      return false;
    }

    // 4. Salva versione installata
    await _updateService.salvaVersioneInstallata(packageId, versione);
    debugPrint('[PKG] Pacchetto API installato — versione $versione');

    return true;
  }

  // Controlla con l'endpoint reale (/check/) se il pacchetto sul
  // server e' cambiato, e lo scarica SOLO in quel caso. Sostituisce il
  // criterio "a tempo" (24h) usato in precedenza come unico criterio di
  // verita' — ora le 24h in UpdateService servono solo a decidere OGNI
  // QUANTO chiamare questo metodo (throttling), non piu' se scaricare.
  // MODIFICATO — usa _authService iniettato, stesso beneficio del metodo sopra.
  Future<SyncResult> sincronizzaSeCambiato({
    required String packageId,
    required String versione,
    void Function(String messaggio)? onStato,
  }) async {
    if (!_authService.isLoggato) {
      onStato?.call('Autenticazione in corso...');
      final loginRiuscito = await _authService.login('utente2', 'utente2');
      if (!loginRiuscito) {
        debugPrint(
          '[PKG] Login fallito — impossibile controllare aggiornamenti',
        );
        return const SyncResult(successo: false, scaricato: false);
      }
    } else {
      debugPrint('[PKG] Gia\' loggato — salto il login');
    }

    // 2. Controlla se il pacchetto e' cambiato sul server
    onStato?.call('Controllo aggiornamenti...');
    final cambiato = await _authService.pacchettoCambiato();

    if (cambiato == false) {
      debugPrint('[PKG] Pacchetto non cambiato — nessun download necessario');
      // Aggiorniamo comunque il timestamp di controllo, cosi' UpdateService
      // sa che abbiamo verificato di recente (throttling, non "verita'")
      await _updateService.salvaVersioneInstallata(packageId, versione);
      return const SyncResult(successo: true, scaricato: false);
    }

    if (cambiato == null) {
      debugPrint(
        '[PKG] Check fallito (errore di rete) — provo comunque a scaricare per sicurezza',
      );
    } else {
      debugPrint('[PKG] Pacchetto cambiato sul server — scarico');
    }

    // 3. Scarica il pacchetto ZIP come bytes
    onStato?.call('Download pacchetto in corso...');
    final bytes = await _authService.scaricaPacchetto();

    if (bytes == null || bytes.isEmpty) {
      debugPrint('[PKG] Pacchetto vuoto o errore download');
      return const SyncResult(successo: false, scaricato: false);
    }

    // 4. Estrae i file su disco con gestione errori dettagliata
    onStato?.call('Estrazione in corso...');
    try {
      await _estraiBytes(bytes, packageId);
    } catch (e, stack) {
      debugPrint('[PKG] ERRORE ESTRAZIONE: $e');
      debugPrint('[PKG] STACK: $stack');
      return const SyncResult(successo: false, scaricato: false);
    }

    // 5. Salva versione installata
    await _updateService.salvaVersioneInstallata(packageId, versione);
    debugPrint('[PKG] Pacchetto aggiornato — versione $versione (check reale)');

    return const SyncResult(successo: true, scaricato: true);
  }

  // Legge info.json di un manoscritto dal disco (vecchia struttura)
  Future<Map<String, dynamic>?> leggiInfoManoscritto(
    String packageId,
    String collectionId,
    String msId,
  ) async {
    final path = 'collections/$collectionId/manuscripts/$msId/info.json';
    return await _storage.leggiJson(packageId, path);
  }

  // Legge collection.json dal disco (vecchia struttura)
  Future<Map<String, dynamic>?> leggiCollection(
    String packageId,
    String collectionId,
  ) async {
    return await _storage.leggiJson(
      packageId,
      'collections/$collectionId/collection.json',
    );
  }

  // Verifica se il pacchetto e' gia' estratto
  Future<bool> isPacchettoInstallato(String packageId) async {
    return await _storage.pacchettoPresenteSync(packageId);
  }

  // Controlla se c'e' un aggiornamento disponibile
  Future<bool> isAggiornamentoDisponibile(
    String packageId,
    String versioneManifest,
  ) async {
    return await _updateService.isAggiornamentoDisponibile(
      packageId,
      versioneManifest,
    );
  }

  // Lista file nel ZIP (per test)
  Future<List<String>> listaFile() async {
    final archive = await _caricaArchivio();
    return archive.files.where((f) => f.isFile).map((f) => f.name).toList();
  }

  // --- NUOVA STRUTTURA PACCHETTO ---

  // Legge books.json — lista di tutti i libri
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
  Future<List<CollectionV2Model>> leggiCollezioniV2(String packageId) async {
    final contenuto = await _storage.leggiFile(packageId, 'collections.json');
    if (contenuto == null) return [];
    // Debug temporaneo — stampa il contenuto raw per vedere la struttura
    debugPrint('[PKG] collections.json raw: $contenuto');
    final lista = jsonDecode(contenuto) as List;
    return lista.map((c) => CollectionV2Model.fromJson(c)).toList();
  }

  // Legge i libri di una specifica collezione
  Future<List<BookModel>> leggiLibriDiCollezione(
    String packageId,
    String collectionId,
  ) async {
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
