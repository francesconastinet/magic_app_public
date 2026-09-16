// TODO: svuotare liste libri/collezioni e decommentare caricamento dati

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../services/storage_service.dart';
import '../core/app_config.dart';

class CatalogueRepository extends ChangeNotifier {
  final StorageService _storage;

  List<BookModel> _libri = [
    BookModel(
      id: 'c36c420b-8096-4989-b4f0-0d9a5212fff4',
      titolo: 'Divina Commedia',
      autore: 'Dante Alighieri',
      anno: '1321',
      status: 'validating',
      multimedia: [
        MediaItem(
          tipo: MediaType.video,
          titolo: 'Spiegazione in 2 minuti',
          url: 'assets/media/video_01.mp4',
          descrizione: '',
        ),
        MediaItem(
          tipo: MediaType.audio,
          titolo: 'Lettura Canto I',
          url: 'assets/media/audio_01.mp3',
          descrizione: '',
        ),
        MediaItem(
          tipo: MediaType.testo,
          titolo: 'Riassunto trama',
          url: 'assets/media/testo_01.txt',
          descrizione: '',
        ),
        MediaItem(
          tipo: MediaType.immagine,
          titolo: 'Copertina del libro',
          url: 'assets/media/immagine_01.png',
          descrizione: '',
        ),
        MediaItem(
          tipo: MediaType.immagine,
          titolo: 'Struttura Inferno',
          url: 'assets/media/immagine_02.png',
          descrizione: '',
        ),
        MediaItem(
          tipo: MediaType.pdf,
          titolo: 'Pdf Canto I',
          url: 'assets/media/pdf_01.pdf',
          descrizione: '',
        ),
        MediaItem(
          tipo: MediaType.linkEsterno,
          titolo: 'Parafrasi Divina Commedia',
          url: 'https://divinacommedia.weebly.com/',
          descrizione: '',
        ),
      ],
    ),
    BookModel(
      id: "4156742e-c213-4899-a2c0-833c380faccc",
      titolo: "Promessi Sposi",
      autore: "Alessandro Manzoni",
      anno: "1827",
      status: "validating",
      multimedia: [
        MediaItem(
          tipo: MediaType.audio,
          titolo: 'Lettura Capitolo 1',
          url: 'assets/media/audio_01.mp3',
          descrizione: '',
        ),
        for (var i = 1; i <= 10; i++)
          MediaItem(
            tipo: MediaType.testo,
            titolo: 'Riassunto Capitolo $i',
            url: 'assets/media/testo_01.txt',
            descrizione: '',
          ),
        MediaItem(
          tipo: MediaType.pdf,
          titolo: 'Pdf Capitolo 1',
          url: 'assets/media/pdf_01.pdf',
          descrizione: '',
        ),
      ],
    ),
    BookModel(
      id: "affc62ac-111c-402f-b608-f2440fea2a66",
      titolo: "Orlando Furioso",
      autore: "Ludovico Ariosto",
      anno: "1516",
      status: "validating",
      multimedia: [],
    ),
    BookModel(
      id: "81a735b6-e4b1-45e6-b28c-15a7068dc9ec",
      titolo: "Aminta",
      autore: "Torquato Tasso",
      anno: "1580",
      status: "validating",
      multimedia: [],
    ),
    BookModel(
      id: "6f938283-eacc-439d-956b-2793a804a335",
      titolo: "Gerusalemme liberata",
      autore: "Torquato Tasso",
      anno: "1581",
      status: "validating",
      multimedia: [],
    ),
    BookModel(
      id: "5721903c-bbc8-4e68-abba-90ab8d749be3",
      titolo: "Jeff Hawke",
      autore: "Sydney Jordan",
      anno: "1955",
      status: "validating",
      multimedia: [],
    ),
    BookModel(
      id: "88328857-3a16-4c0f-b041-33218f58506c",
      titolo: "Dei sepolcri",
      autore: "Ugo Foscolo",
      anno: "1807",
      status: "validating",
      multimedia: [],
    ),
  ];
  List<CollectionV2Model> _collezioni = [
    CollectionV2Model(
      id: 'coll_01',
      name: 'Percorso Medievale',
      description:
          'Una selezione di manoscritti risalenti al periodo medievale.',
      bookIds: [
        'affc62ac-111c-402f-b608-f2440fea2a66',
        '81a735b6-e4b1-45e6-b28c-15a7068dc9ec',
        'c36c420b-8096-4989-b4f0-0d9a5212fff4',
      ],
    ),
  ];

  CatalogueRepository({required this._storage});

  List<BookModel> get libri => _libri;
  List<CollectionV2Model> get collezioni => _collezioni;

  // Legge i JSON e li salva nella RAM
  Future<void> caricaDatiLocali() async {
    try {
      final packageId = AppConfig.packageId;

      // 1. Carica Libri (mantenendo il filtro difensivo di prima)
      // final booksJson = await _storage.leggiFile(packageId, 'books.json');
      // if (booksJson != null) {
      //   final lista = jsonDecode(booksJson) as List;
      //   _libri = lista
      //       .map((b) => BookModel.fromJson(b))
      //       .where((b) => b.titolo.trim().isNotEmpty) // Filtro validità
      //       .toList();
      // }

      // 2. Carica Collezioni
      // final collJson = await _storage.leggiFile(packageId, 'collections.json');
      // if (collJson != null) {
      //   final lista = jsonDecode(collJson) as List;
      //   _collezioni = lista.map((c) => CollectionV2Model.fromJson(c)).toList();
      // }

      // 3. SANITIZZAZIONE DATI
      // Creiamo un Set con solo gli ID dei libri validi
      final idLibriValidi = _libri.map((b) => b.id).toSet();

      // Scorriamo le collezioni e rimuoviamo gli ID invalidi
      for (var collezione in _collezioni) {
        collezione.bookIds.retainWhere((id) => idLibriValidi.contains(id));
      }

      debugPrint(
        '[CATALOGUE REPO] Caricati in RAM: ${_libri.length} opere, ${_collezioni.length} collezioni.',
      );
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
