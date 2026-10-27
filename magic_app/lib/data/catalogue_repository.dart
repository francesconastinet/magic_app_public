// TODO: svuotare liste libri/collezioni e decommentare caricamento dati

// l'import serve solo al caricamento dei JSON, che per ora è commentato
// (vedi TODO in cima): ignoro il warning "unused import" invece di toglierlo
// ignore: unused_import
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../services/storage_service.dart';
import '../core/app_config.dart';

class CatalogueRepository extends ChangeNotifier {
  //  — usato solo dal caricamento dei JSON, che per ora è commentato
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
      // — id aggiornato a quello del database della chat (con i tenant
      // gli id sono cambiati)
      // (riga originale: id: "4156742e-c213-4899-a2c0-833c380faccc",)
      id: "87ee5d89-9020-44e0-a0f9-c329312be12c",
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
      //  — id aggiornato a quello del database della chat
      // (riga originale: id: "81a735b6-e4b1-45e6-b28c-15a7068dc9ec",)
      id: "2a9beabc-cf7a-4994-99d5-86af26cc9732",
      titolo: "Aminta",
      autore: "Torquato Tasso",
      anno: "1580",
      status: "validating",
      multimedia: [],
    ),
    BookModel(
      //  — id aggiornato a quello del database della chat
      // (riga originale: id: "6f938283-eacc-439d-956b-2793a804a335",)
      id: "6acf4254-f437-4ff7-9382-abb9c643bb17",
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
    //  — i libri temporanei di test (qui sotto, commentati) non sono nel
    // database della chat e la chat con le fonti selezionate non funzionava
    // ("Nessun id valido trovato"). Le copertine del modello ora sono collegate
    // a libri veri del database (id presi da GET /books)
    BookModel(
      id: "0e6ea323-a308-4968-be01-fa57976fbde3",
      titolo: "Novelle vol. 2",
      autore: "Giovanni Sercambi",
      anno: "",
      status: "validating",
      multimedia: [],
    ),
    BookModel(
      id: "46d17b4f-2e35-404c-b1b6-cc557262342e",
      titolo: "Puerili e abbozzi vari",
      autore: "Giacomo Leopardi",
      anno: "",
      status: "validating",
      multimedia: [],
    ),
    BookModel(
      id: "87991236-5c32-4c7d-a4ac-ebcb97eaf5b6",
      titolo: "Lirica",
      autore: "Ludovico Ariosto",
      anno: "",
      status: "validating",
      multimedia: [],
    ),
    BookModel(
      id: "70394cd9-055b-4591-bcf7-1dade2a4a969",
      titolo: "Accanto A Te L'amore",
      autore: "Amodio Tortora",
      anno: "",
      status: "validating",
      multimedia: [],
    ),
    BookModel(
      id: "7d8c16f6-c3fa-47d9-8d9a-4a94cda30721",
      titolo: "Braccheggio Ambigrammatico",
      autore: "Fenringard",
      anno: "",
      status: "validating",
      multimedia: [],
    ),
    // (righe originali, libri temporanei di test:)
    //     // NUOVO — libri TEMPORANEI per il test del modello di Rosario (non sono nel database)
    //     BookModel(
    //       id: 'test_davenia',
    //       titolo: "Cose che nessuno sa",
    //       autore: "Alessandro D'Avenia",
    //       anno: '',
    //       status: 'validating',
    //       multimedia: [],
    //     ),
    //     BookModel(
    //       id: 'test_mae',
    //       titolo: "'O Maé",
    //       autore: "Luigi Garlando",
    //       anno: '',
    //       status: 'validating',
    //       multimedia: [],
    //     ),
    //     BookModel(
    //       id: 'test_misura',
    //       titolo: "La misura del mondo",
    //       autore: "Daniel Kehlmann",
    //       anno: '',
    //       status: 'validating',
    //       multimedia: [],
    //     ),
    //     BookModel(
    //       id: 'test_rabbia',
    //       titolo: "La rabbia e l'orgoglio",
    //       autore: "Oriana Fallaci",
    //       anno: '',
    //       status: 'validating',
    //       multimedia: [],
    //     ),
    //     BookModel(
    //       id: 'test_stelle',
    //       titolo: "Ma le stelle quante sono",
    //       autore: "Giulia Carcasi",
    //       anno: '',
    //       status: 'validating',
    //       multimedia: [],
    //     ),
    //     BookModel(
    //       id: 'test_visconte',
    //       titolo: "Il visconte dimezzato",
    //       autore: "Italo Calvino",
    //       anno: '',
    //       status: 'validating',
    //       multimedia: [],
    //     ),
    //     BookModel(
    //       id: 'test_wonder',
    //       titolo: "Wonder",
    //       autore: "R.J. Palacio",
    //       anno: '',
    //       status: 'validating',
    //       multimedia: [],
    //     ),
  ];

  // TEMPORANEO: collega le label del modello  (nomi delle cartelle
  // del dataset) ai libri temporanei qui sopra. Da togliere quando le cartelle del
  // dataset useranno gli id veri dei libri.
  //  — le label ora puntano agli id di libri veri del database della
  // chat 
  // (righe originali:
  //   'davenia': 'test_davenia',
  //   'mae': 'test_mae',
  //   'misura': 'test_misura',
  //   'rabbia': 'test_rabbia',
  //   'stelle': 'test_stelle',
  //   'visconte': 'test_visconte',
  //   'wonder': 'test_wonder',)
  static const Map<String, String> _labelAId = {
    'davenia': '2a9beabc-cf7a-4994-99d5-86af26cc9732', // Aminta
    'mae': '6acf4254-f437-4ff7-9382-abb9c643bb17', // Gerusalemme liberata
    'misura': '46d17b4f-2e35-404c-b1b6-cc557262342e', // Puerili e abbozzi vari
    'rabbia': '87991236-5c32-4c7d-a4ac-ebcb97eaf5b6', // Lirica
    'stelle': '70394cd9-055b-4591-bcf7-1dade2a4a969', // Accanto A Te L'amore
    'visconte': '7d8c16f6-c3fa-47d9-8d9a-4a94cda30721', // Braccheggio Ambigrammatico
    'wonder': '0e6ea323-a308-4968-be01-fa57976fbde3', // Novelle vol. 2
  };

  final List<CollectionV2Model> _collezioni = [
    CollectionV2Model(
      id: 'coll_01',
      name: 'Percorso Medievale',
      description:
          'Una selezione di manoscritti risalenti al periodo medievale.',
      bookIds: [
        'affc62ac-111c-402f-b608-f2440fea2a66',
        //  — id di Aminta aggiornato a quello del database
        // (riga originale: '81a735b6-e4b1-45e6-b28c-15a7068dc9ec',)
        '2a9beabc-cf7a-4994-99d5-86af26cc9732',
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
      //  — usata solo nelle righe commentate sotto: ignoro il warning
      // "unused local variable" invece di toglierla
      // ignore: unused_local_variable
      final packageId = AppConfig.packageId;

      // 1. Carica Libri (con il filtro difensivo)
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
      // Crea un Set con solo gli ID dei libri validi
      final idLibriValidi = _libri.map((b) => b.id).toSet();

      // Scorre le collezioni e rimuvove gli ID invalidi
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
    //  — cerca la label esatta del modello (es. "davenia") tra i libri temporanei
    final idDaLabel = _labelAId[nomeOpera.toLowerCase().trim()];
    if (idDaLabel != null) {
      for (final o in _libri) {
        if (o.id == idDaLabel) return o;
      }
    }

    try {
      //  — confronto senza maiuscole/minuscole e in entrambi i versi,
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
      //  — se non trova nessun libro restituisce null (prima restituiva
      // sempre il primo libro, aprendo un'opera sbagliata)
      // (riga originale: return _libri.isNotEmpty ? _libri.first : null;)
      return null;
    }
  }
}