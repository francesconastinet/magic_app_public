// TODO: svuotare liste libri/collezioni e decommentare caricamento dati

// l'import serve solo al caricamento dei JSON, che per ora è commentato
// (vedi TODO in cima): ignoro il warning "unused import" invece di toglierlo
// (ora jsonDecode si usa anche per le risposte delle API collezioni e
// documenti, quando arrivano come stringa)
// ignore: unused_import
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../services/storage_service.dart';
import '../core/app_config.dart';

class CatalogueRepository extends ChangeNotifier {
  //  — usato solo dal caricamento dei JSON, che per ora è commentato
  // (vedi TODO in cima): ignoro il warning "unused field" invece di toglierlo
  // ignore: unused_field
  final StorageService _storage;

  // client per le API pubbliche del backend (collezioni e documenti)
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  // stato del caricamento delle collezioni e dei libri delle collezioni
  bool _isLoadingCollezioni = false;
  bool _isLoadingLibri = false;
  // collezioni di cui i libri sono gia' stati scaricati (per non rifare
  // la chiamata ogni volta che si tocca lo stesso chip)
  final Set<String> _collezioniCaricate = {};

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

  // le collezioni ora arrivano da GET /api/collections/public/magic/
  // (vedi caricaCollezioni). Il percorso medievale scritto a mano e' stato tolto.
  // (righe originali:
  //   CollectionV2Model(
  //     id: 'coll_01',
  //     name: 'Percorso Medievale',
  //     description:
  //         'Una selezione di manoscritti risalenti al periodo medievale.',
  //     bookIds: [
  //       'affc62ac-111c-402f-b608-f2440fea2a66',
  //       //  — id di Aminta aggiornato a quello del database
  //       // (riga originale: '81a735b6-e4b1-45e6-b28c-15a7068dc9ec',)
  //       '2a9beabc-cf7a-4994-99d5-86af26cc9732',
  //       'c36c420b-8096-4989-b4f0-0d9a5212fff4',
  //     ],
  //   ),)
  final List<CollectionV2Model> _collezioni = [];

  // (riga originale: CatalogueRepository({required this._storage});)
  CatalogueRepository({required this._storage}) {
    _applicaMultimediaDemo();
  }

  // TEMPORANEO (demo): i libri senza contenuti multimediali prendono quelli
  // della Divina Commedia, cosi' scansionando qualsiasi copertina (es.
  // "wonder" -> Novelle vol. 2) le bubbles a destra si vedono e funzionano.
  // I contenuti parlano della Divina Commedia: poi si sostituiscono con quelli
  // veri di ogni libro. Per toglierlo basta non chiamare questo metodo.
  static const String _idLibroDemo = 'c36c420b-8096-4989-b4f0-0d9a5212fff4';

  void _applicaMultimediaDemo() {
    List<MediaItem>? demo;
    for (final o in _libri) {
      if (o.id == _idLibroDemo) {
        demo = o.multimedia;
        break;
      }
    }
    if (demo == null || demo.isEmpty) return;

    var aggiornati = 0;
    for (var i = 0; i < _libri.length; i++) {
      final libro = _libri[i];
      if (libro.multimedia.isNotEmpty) continue;
      _libri[i] = BookModel(
        id: libro.id,
        titolo: libro.titolo,
        autore: libro.autore,
        anno: libro.anno,
        status: libro.status,
        multimedia: demo,
        collectionId: libro.collectionId,
      );
      aggiornati++;
    }
    if (aggiornati > 0) {
      debugPrint(
        '[CATALOGUE REPO] Multimedia demo (Divina Commedia) assegnati a '
        '$aggiornati libri',
      );
    }
  }

  List<BookModel> get libri => _libri;
  List<CollectionV2Model> get collezioni => _collezioni;
  bool get isLoadingCollezioni => _isLoadingCollezioni;
  bool get isLoadingLibri => _isLoadingLibri;

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
      // (le collezioni della GET pubblica non hanno la lista libri: se e'
      // vuota si salta, la lista di default non e' modificabile)
      for (var collezione in _collezioni) {
        if (collezione.bookIds.isEmpty) continue;
        collezione.bookIds.retainWhere((id) => idLibriValidi.contains(id));
      }

      debugPrint(
        '[CATALOGUE REPO] Caricati in RAM: ${_libri.length} opere, ${_collezioni.length} collezioni.',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[CATALOGUE REPO] Errore caricamento JSON: $e');
    }

    // collezioni pubbliche dal backend (Classici italiani, Test 01, ...)
    await caricaCollezioni();
  }

  // ==========================================
  // COLLEZIONI E LIBRI DAL BACKEND
  // ==========================================

  // scarica le collezioni pubbliche da GET /api/collections/public/magic/.
  // Ogni collezione ha id, tenant, name, description, subject, visibility.
  // Se la chiamata fallisce la lista resta com'era.
  Future<void> caricaCollezioni() async {
    if (_isLoadingCollezioni) return;
    _isLoadingCollezioni = true;
    notifyListeners();

    final url = '${AppConfig.apiBaseUrl}/api/collections/public/magic/';

    try {
      debugPrint('[CATALOGUE REPO] GET $url');
      final response = await _dio.get(url);
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      final lista = _estraiLista(data);
      final nuove = lista
          .whereType<Map>()
          .map((c) => CollectionV2Model.fromJson(Map<String, dynamic>.from(c)))
          .where((c) => c.id.isNotEmpty && c.name.trim().isNotEmpty)
          .toList();

      _collezioni
        ..clear()
        ..addAll(nuove);

      debugPrint(
        '[CATALOGUE REPO] Collezioni caricate: '
        '${_collezioni.map((c) => c.name).toList()}',
      );
    } on DioException catch (e) {
      debugPrint(
        '[CATALOGUE REPO] Errore GET collezioni: '
        '${e.response?.statusCode} ${e.response?.data ?? e.message}',
      );
    } catch (e, stack) {
      debugPrint('[CATALOGUE REPO] Errore parsing collezioni: $e\n$stack');
    } finally {
      _isLoadingCollezioni = false;
      notifyListeners();
    }

    // si scaricano subito i libri di tutte le collezioni, cosi' ogni libro
    // ha il suo collection_id anche se si entra in chat dalla scansione
    // senza aprire il catalogo (serve per la fonte bloccata)
    for (final c in List<CollectionV2Model>.from(_collezioni)) {
      await caricaLibriCollezione(c.id);
    }
  }

  // scarica i libri di una collezione da
  // GET /api/documents/search/v2/{tenant_id}/ con il collection_id della
  // collezione selezionata. Ai libri scaricati viene messo quel collection_id,
  // cosi' il catalogo li mostra sotto la collezione giusta.
  Future<void> caricaLibriCollezione(
    String collectionId, {
    bool forza = false,
  }) async {
    if (collectionId.isEmpty) return;
    if (!forza && _collezioniCaricate.contains(collectionId)) return;
    if (_isLoadingLibri) return;

    _isLoadingLibri = true;
    notifyListeners();

    final url =
        '${AppConfig.apiBaseUrl}/api/documents/search/v2/${AppConfig.tenantId}/';

    try {
      debugPrint('[CATALOGUE REPO] GET $url collection_id=$collectionId');
      final response = await _dio.get(
        url,
        queryParameters: {'collection_id': collectionId},
      );
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      final lista = _estraiLista(data);
      var aggiunti = 0;
      var aggiornati = 0;

      for (final item in lista.whereType<Map>()) {
        final libro = _libroDaDocumento(
          Map<String, dynamic>.from(item),
          collectionId,
        );
        if (libro == null) continue;

        final index = _libri.indexWhere((o) => o.id == libro.id);
        if (index != -1) {
          // libro gia' presente (es. quelli scritti a mano con i contenuti
          // multimediali): si tengono i suoi dati e si aggiunge il collection_id
          final esistente = _libri[index];
          _libri[index] = BookModel(
            id: esistente.id,
            titolo: esistente.titolo.isNotEmpty
                ? esistente.titolo
                : libro.titolo,
            autore: esistente.autore.isNotEmpty
                ? esistente.autore
                : libro.autore,
            anno: esistente.anno.isNotEmpty ? esistente.anno : libro.anno,
            status: esistente.status,
            multimedia: esistente.multimedia,
            collectionId: libro.collectionId,
          );
          aggiornati++;
        } else {
          _libri.add(libro);
          aggiunti++;
        }
      }

      _collezioniCaricate.add(collectionId);
      // anche i libri arrivati dal server prendono i multimedia demo
      _applicaMultimediaDemo();
      debugPrint(
        '[CATALOGUE REPO] Libri collezione $collectionId: '
        '${lista.length} ricevuti, $aggiunti aggiunti, $aggiornati aggiornati',
      );
    } on DioException catch (e) {
      debugPrint(
        '[CATALOGUE REPO] Errore GET libri collezione: '
        '${e.response?.statusCode} ${e.response?.data ?? e.message}',
      );
    } catch (e, stack) {
      debugPrint('[CATALOGUE REPO] Errore parsing libri collezione: $e\n$stack');
    } finally {
      _isLoadingLibri = false;
      notifyListeners();
    }
  }

  // la risposta puo' essere direttamente una lista oppure un oggetto con la
  // lista dentro (results, items, documents, data, hits)
  List _estraiLista(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final chiave in ['results', 'items', 'documents', 'data', 'hits']) {
        final valore = data[chiave];
        if (valore is List) return valore;
      }
    }
    return [];
  }

  // converte un documento della search v2 in BookModel. Legge i nomi di
  // campo piu' probabili (id/document_id, title/titolo, author/autore,
  // year/date/anno). Ritorna null se manca l'id o il titolo.
  BookModel? _libroDaDocumento(Map<String, dynamic> json, String collectionId) {
    String testo(List<String> chiavi) {
      for (final k in chiavi) {
        final v = json[k];
        if (v == null) continue;
        if (v is List) {
          final unito = v.map((e) => e.toString()).join(', ').trim();
          if (unito.isNotEmpty) return unito;
          continue;
        }
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    final id = testo(['id', 'document_id', 'work_id', 'book_id']);
    final titolo = testo(['title', 'titolo', 'name']);
    if (id.isEmpty || titolo.isEmpty) return null;

    // il collection_id del libro e' sempre l'id della collezione chiesta
    // (UUID preso da GET /api/collections/public/magic/). Il campo
    // collection_id del documento non si usa: puo' essere una lista o un
    // valore non UUID, e la chat rispondeva 422 "collection_id deve essere
    // un UUID valido".
    // (righe precedenti:
    //   final idCollezione = testo(['collection_id', 'collectionId']);
    //   collectionId: idCollezione.isNotEmpty ? idCollezione : collectionId,)
    final idCollezioneDocumento = testo(['collection_id', 'collectionId']);
    if (idCollezioneDocumento.isNotEmpty &&
        idCollezioneDocumento != collectionId) {
      debugPrint(
        '[CATALOGUE REPO] Libro $id: collection_id del documento '
        '"$idCollezioneDocumento" ignorato, si usa $collectionId',
      );
    }

    return BookModel(
      id: id,
      titolo: titolo,
      autore: testo(['author', 'autore', 'authors']),
      anno: testo(['year', 'anno', 'date']),
      status: testo(['status']),
      multimedia: [],
      collectionId: collectionId,
    );
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