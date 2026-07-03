import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class PackageStorage {
  // Restituisce la cartella radice per i pacchetti MAGIC
  Future<Directory> get _baseDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/magic_packages');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // Percorso cartella di un pacchetto specifico
  Future<String> percorsoPacchetto(String packageId) async {
    final base = await _baseDir;
    return '${base.path}/$packageId';
  }

  // Salva un file nel pacchetto
  Future<void> salvaFile(String packageId, String relativePath,
      List<int> bytes) async {
    final base = await _baseDir;
    final file = File('${base.path}/$packageId/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  // Legge un file dal pacchetto come stringa
  Future<String?> leggiFile(String packageId, String relativePath) async {
    final base = await _baseDir;
    final file = File('${base.path}/$packageId/$relativePath');
    if (!await file.exists()) return null;
    return await file.readAsString();
  }

  // Legge un file come JSON
  Future<Map<String, dynamic>?> leggiJson(
      String packageId, String relativePath) async {
    final contenuto = await leggiFile(packageId, relativePath);
    if (contenuto == null) return null;
    return jsonDecode(contenuto) as Map<String, dynamic>;
  }

  // Verifica se un pacchetto e' installato
  Future<bool> pacchettoPresenteSync(String packageId) async {
    final base = await _baseDir;
    final dir = Directory('${base.path}/$packageId');
    return await dir.exists();
  }

  // Lista i pacchetti installati
  Future<List<String>> listaPacchetti() async {
    final base = await _baseDir;
    if (!await base.exists()) return [];
    final dirs = await base
        .list()
        .where((e) => e is Directory)
        .map((e) => e.path.split('/').last)
        .toList();
    return dirs;
  }

  // Elimina un pacchetto
  Future<void> eliminaPacchetto(String packageId) async {
    final base = await _baseDir;
    final dir = Directory('${base.path}/$packageId');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}