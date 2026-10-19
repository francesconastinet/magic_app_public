// TODO: svuotare liste libri/collezioni e decommentare caricamento dati

// MODIFICATO — l'import serve solo al caricamento dei JSON, che per ora e' commentato
// (vedi TODO in cima): ignoro il warning "unused import" invece di toglierlo
// ignore: unused_import
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../services/storage_service.dart';
import '../core/app_config.dart';

class CatalogueRepository extends ChangeNotifier {
  // MODIFICATO — usato solo dal caricamento dei JSON, che per ora e' commentato
  // (vedi TODO in cima): ignoro il warning "unused field" invece di toglierlo
  // ignore: unused_field
  final StorageService _storage;

  final List<BookModel> _libri = [
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
      titolo: "Future directions",
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
    // NUOVO — libri TEMPORANEI per il test del modello di Rosario (non sono nel database)
    BookModel(
      id: 'test_davenia',
      titolo: "Cose che nessuno sa",
      autore: "Alessandro D'Avenia",
      anno: '',
      status: 'validating',
      multimedia: [],
    ),
    BookModel(
      id: 'test_mae',
      titolo: "'O Maé",
      autore: "Luigi Garlando",
      anno: '',
      status: 'validating',
      multimedia: [],
    ),
    BookModel(
      id: 'test_misura',
      titolo: "La misura del mondo",
      autore: "Daniel Kehlmann",
      anno: '',
      status: 'validating',
      multimedia: [],
    ),
    BookModel(
      id: 'test_rabbia',
      titolo: "La rabbia e l'orgoglio",
      autore: "Oriana Fallaci",
      anno: '',
      status: 'validating',
      multimedia: [],
    ),
    BookModel(
      id: 'test_stelle',
      titolo: "Ma le stelle quante sono",
      autore: "Giulia Carcasi",
      anno: '',
      status: 'validating',
      multimedia: [],
    ),
    BookModel(
      id: 'test_visconte',
      titolo: "Il visconte dimezzato",
      autore: "Italo Calvino",
      anno: '',
      status: 'validating',
      multimedia: [],
    ),
    BookModel(
      id: 'test_wonder',
      titolo: "Wonder",
      autore: "R.J. Palacio",
      anno: '',
      status: 'validating',
      multimedia: [],
    ),
  ];

  // NUOVO — TEMPORANEO: collega le label del modello di Rosario (nomi delle cartelle
  // del dataset) ai libri temporanei qui sopra. Da togliere quando le cartelle del
  // dataset useranno gli id veri dei libri.
  static const Map<String, String> _labelAId = {
    'davenia': 'test_davenia',
    'mae': 'test_mae',
    'misura': 'test_misura',
    'rabbia': 'test_rabbia',
    'stelle': 'test_stelle',
    'visconte': 'test_visconte',
    'wonder': 'test_wonder',
  };

  final List<CollectionV2Model> _collezioni = [
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
      // MODIFICATO — usata solo nelle righe commentate sotto: ignoro il warning
      // "unused local variable" invece di toglierla
      // ignore: unused_local_variable
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
    // NUOVO — prima cerco la label esatta del modello (es. "davenia") tra i libri temporanei
    final idDaLabel = _labelAId[nomeOpera.toLowerCase().trim()];
    if (idDaLabel != null) {
      for (final o in _libri) {
        if (o.id == idDaLabel) return o;
      }
    }

    try {
      // MODIFICATO — confronto senza maiuscole/minuscole e in entrambi i versi,
      // perche' le label del modello sono minuscole (es. "sepolcri", "divina")
      // mentre i titoli sono "Dei sepolcri", "Divina Commedia"
      // (riga originale:
      //   return _libri.firstWhere(
      //     (o) => nomeOpera.contains(o.titolo.split(' ').first),
      //   );)
      final nome = nomeOpera.toLowerCase().trim();
      return _libri.firstWhere(
        (o) =>
            nome.contains(o.titolo.split(' ').first.toLowerCase()) ||
            o.titolo.toLowerCase().contains(nome),
      );
    } catch (_) {
      // MODIFICATO — se non trova nessun libro restituisce null (prima restituiva
      // sempre il primo libro, aprendo un'opera sbagliata)
      // (riga originale: return _libri.isNotEmpty ? _libri.first : null;)
      return null;
    }
  }
}