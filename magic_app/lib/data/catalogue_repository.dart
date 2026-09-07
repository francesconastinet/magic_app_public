import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../services/storage_service.dart';
import '../core/app_config.dart';

class CatalogueRepository extends ChangeNotifier {
  final StorageService _storage;

  List<BookModel> _libri = [];
  List<CollectionV2Model> _collezioni = [];

  CatalogueRepository({required this._storage});

  List<BookModel> get libri => _libri;
  List<CollectionV2Model> get collezioni => _collezioni;

  // Legge i JSON e li salva nella RAM
  Future<void> caricaDatiLocali() async {
    try {
      final packageId = AppConfig.packageId;

      // 1. Carica Libri (mantenendo il filtro difensivo di prima)
      final booksJson = await _storage.leggiFile(packageId, 'books.json');
      if (booksJson != null) {
        final lista = jsonDecode(booksJson) as List;
        _libri = lista
            .map((b) => BookModel.fromJson(b))
            .where((b) => b.titolo.trim().isNotEmpty) // Filtro validità
            .toList();
      }

      // 2. Carica Collezioni
      final collJson = await _storage.leggiFile(packageId, 'collections.json');
      if (collJson != null) {
        final lista = jsonDecode(collJson) as List;
        _collezioni = lista.map((c) => CollectionV2Model.fromJson(c)).toList();
      }

      // 3. SANITIZZAZIONE DATI
      // Creiamo un Set con solo gli ID dei libri validi
      final idLibriValidi = _libri.map((b) => b.id).toSet();

      // Scorriamo le collezioni e rimuoviamo gli ID invalidi
      for (var collezione in _collezioni) {
        collezione.bookIds.retainWhere((id) => idLibriValidi.contains(id));
      }

      debugPrint('[CATALOGUE REPO] Caricati in RAM: ${_libri.length} opere, ${_collezioni.length} collezioni.');
      notifyListeners();
    } catch (e) {
      debugPrint('[CATALOGUE REPO] Errore caricamento JSON: $e');
    }
  }

  BookModel? trovaPerNome(String nomeOpera) {
    try {
      return _libri.firstWhere(
        (o) => nomeOpera.contains(o.titolo.split(' ').first),
      );
    } catch (_) {
      return _libri.isNotEmpty ? _libri.first : null;
    }
  }
}
