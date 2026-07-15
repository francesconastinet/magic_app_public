import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class UpdateService {
  // Salva la versione installata su disco dopo il download
  Future<void> salvaVersioneInstallata(
      String packageId, String version) async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(
        '${docs.path}/magic_packages/$packageId/installed.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      'version': version,
      'installedAt': DateTime.now().toIso8601String(),
    }));
    debugPrint('Versione $version salvata per $packageId');
  }

  // Legge la versione installata dal disco
  Future<String?> leggiVersioneInstallata(String packageId) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File(
          '${docs.path}/magic_packages/$packageId/installed.json');
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return json['version'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Confronta versione locale con quella del manifest
  // Restituisce true se c'e' un aggiornamento disponibile
  Future<bool> isAggiornamentoDisponibile(
      String packageId, String versioneManifest) async {
    final versioneInstallata = await leggiVersioneInstallata(packageId);
    if (versioneInstallata == null) return true; // mai installato
    return versioneInstallata != versioneManifest;
  }

  // Controlla se e' necessario sincronizzare il pacchetto in background.
  // Restituisce true se il pacchetto non e' mai stato installato, oppure
  // se sono passate piu' di [oreLimite] ore dall'ultimo download. (endpoint
  // /check/ reale): non avendo un endpoint di versione, ci basiamo sul
  // timestamp locale salvato in installed.json da salvaVersioneInstallata().
  // Ora questo metodo serve solo a decidere OGNI QUANTO chiamare il check
  // reale (throttling) — vedi PackageService.sincronizzaSeCambiato.
  Future<bool> isSincronizzazioneNecessaria(
    String packageId, {
    int oreLimite = 24,
  }) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File(
          '${docs.path}/magic_packages/$packageId/installed.json');

      if (!await file.exists()) {
        debugPrint(
            '[SYNC] Nessun pacchetto installato per $packageId — sync necessaria');
        return true; // mai installato -> serve scaricare
      }

      final json = jsonDecode(await file.readAsString());
      final installedAtStr = json['installedAt'] as String?;

      if (installedAtStr == null) {
        debugPrint('[SYNC] installed.json senza installedAt — sync necessaria');
        return true;
      }

      final installedAt = DateTime.parse(installedAtStr);
      final oreTrascorse = DateTime.now().difference(installedAt).inHours;
      final necessaria = oreTrascorse >= oreLimite;

      debugPrint(
          '[SYNC] Ultimo download $oreTrascorse ore fa (limite $oreLimite h) -> sync ${necessaria ? "necessaria" : "non necessaria"}');

      return necessaria;
    } catch (e) {
      // In caso di dubbio (file corrotto, errore di parsing) meglio
      // riprovare il download piuttosto che restare con dati vecchi
      debugPrint('[SYNC] Errore lettura installed.json: $e — sync necessaria per sicurezza');
      return true;
    }
  }
}