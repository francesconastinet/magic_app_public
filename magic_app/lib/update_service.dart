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
}