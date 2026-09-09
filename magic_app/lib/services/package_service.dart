import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'storage_service.dart';
import 'package:flutter/foundation.dart';
import 'download_service.dart';
import 'update_service.dart';
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
  final StorageService _storage;
  final AuthService _authService;
  final UpdateService _updateService = UpdateService();

  // Dependency injection:
  // PackageService non crea più le sue dipendenze da solo, le riceve
  // dall'esterno (in main.dart, via context.read<...>()). Così si riusa
  // la STESSA istanza di AuthService in tutta l'app, invece di rifare
  // login ogni volta che serve un download.
  PackageService({
    required StorageService storage,
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
      final loginRiuscito = await _authService.login(
        'tenant_magic ',
        'tenant_magic ',
      );
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

  Future<SyncResult> sincronizzaSeCambiato({
    required String packageId,
    required String versione,
    void Function(String messaggio)? onStato,
  }) async {
    if (!_authService.isLoggato) {
      onStato?.call('Autenticazione in corso...');
      final loginRiuscito = await _authService.login(
        'tenant_magic ',
        'tenant_magic ',
      );
      if (!loginRiuscito) {
        debugPrint(
          '[PKG] Login fallito — impossibile controllare aggiornamenti',
        );
        return const SyncResult(successo: false, scaricato: false);
      }
    } else {
      debugPrint('[PKG] Gia\' loggato — salto il login');
    }

    // 1. Controlla se l'app ha già scaricato i file in passato
    final versioneLocale = await _updateService.leggiVersioneInstallata(
      packageId,
    );
    final pacchettoEsisteLocalmente = versioneLocale != null;

    // 2. Controlla se il pacchetto e' cambiato sul server
    onStato?.call('Controllo aggiornamenti...');
    final cambiato = await _authService.pacchettoCambiato();

    // 3. Salta il download solo se non ci sono novità sul server
    // e se ci sono già i file fisicamente sul dispositivo
    if (cambiato == false && pacchettoEsisteLocalmente) {
      debugPrint(
        '[PKG] Pacchetto non cambiato e già presente — nessun download necessario',
      );
      await _updateService.salvaVersioneInstallata(packageId, versione);
      return const SyncResult(successo: true, scaricato: false);
    }

    // Log per capire perché sta scaricando
    if (!pacchettoEsisteLocalmente) {
      debugPrint(
        '[PKG] Dati locali mancanti (prima installazione) — forzo il download',
      );
    } else if (cambiato == true) {
      debugPrint('[PKG] Pacchetto cambiato sul server — scarico aggiornamento');
    }

    // 4. Scarica il pacchetto ZIP come bytes
    onStato?.call('Download pacchetto in corso...');
    final bytes = await _authService.scaricaPacchetto();

    if (bytes == null || bytes.isEmpty) {
      debugPrint('[PKG] Pacchetto vuoto o errore download');
      return const SyncResult(successo: false, scaricato: false);
    }

    // 5. Estrae i file su disco con gestione errori dettagliata
    onStato?.call('Estrazione in corso...');
    try {
      await _estraiBytes(bytes, packageId);
    } catch (e, stack) {
      debugPrint('[PKG] ERRORE ESTRAZIONE: $e');
      debugPrint('[PKG] STACK: $stack');
      return const SyncResult(successo: false, scaricato: false);
    }

    // 6. Salva versione installata
    await _updateService.salvaVersioneInstallata(packageId, versione);
    debugPrint('[PKG] Pacchetto aggiornato — versione $versione (check reale)');

    return const SyncResult(successo: true, scaricato: true);
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
}
