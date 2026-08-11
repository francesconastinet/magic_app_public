import 'models.dart';

class OperaRepository {
  static final List<BookModel> _catalogo = [
    BookModel(
      id: '001',
      titolo: 'Manoscritto Girolamini',
      autore: 'Autore Ignoto',
      anno: 'Sec. XIV-XVII',
      multimedia: [],
    ),
    BookModel(
      id: '002',
      titolo: 'Codice Miniato',
      autore: 'Scuola Napoletana',
      anno: 'Sec. XV',
      multimedia: [],
    ),
    BookModel(
      id: '003',
      titolo: 'Antifonario',
      autore: 'Anonimo sec. XIV',
      anno: 'Sec. XIV',
      multimedia: [],
    ),
    BookModel(
      id: 'xyz',
      titolo: 'Divina Commedia',
      autore: 'Dante Alighieri',
      anno: '1321',
      multimedia: [
        MediaItem(
          tipo: 'video',
          titolo: 'Spiegazione in 2 minuti',
          url: 'assets/media/video_01.mp4',
          descrizione: '',
        ),
        MediaItem(
          tipo: 'audio',
          titolo: 'Lettura Canto I',
          url: 'assets/media/audio_01.mp3',
          descrizione: '',
        ),
        MediaItem(
          tipo: 'testo',
          titolo: 'Riassunto trama',
          url: 'assets/media/testo_01.txt',
          descrizione: '',
        ),
        MediaItem(
          tipo: 'immagine',
          titolo: 'Copertina del libro',
          url: 'assets/media/immagine_01.png',
          descrizione: '',
        ),
        MediaItem(
          tipo: 'immagine',
          titolo: 'Struttura Inferno',
          url: 'assets/media/immagine_02.png',
          descrizione: '',
        ),
        MediaItem(
          tipo: 'pdf',
          titolo: 'Pdf Canto I',
          url: 'assets/media/pdf_01.pdf',
          descrizione: '',
        ),
        MediaItem(
          tipo: 'link_esterno',
          titolo: 'Parafrasi Divina Commedia',
          url: 'https://divinacommedia.weebly.com/',
          descrizione: '',
        ),
      ],
    ),
    BookModel(
      id: '004',
      titolo: 'Promessi Sposi',
      autore: 'Alessandro Manzoni',
      anno: '1827',
      multimedia: [
        MediaItem(
          tipo: 'audio',
          titolo: 'Lettura Capitolo 1',
          url: 'assets/media/audio_01.mp3',
          descrizione: '',
        ),
        for (var i = 1; i <= 10; i++)
          MediaItem(
            tipo: 'testo',
            titolo: 'Riassunto Capitolo $i',
            url: 'assets/media/testo_01.txt',
            descrizione: '',
          ),
        MediaItem(
          tipo: 'pdf',
          titolo: 'Pdf Capitolo 1',
          url: 'assets/media/pdf_01.pdf',
          descrizione: '',
        ),
      ],
    ),
  ];

  // Restituisce tutte le opere
  static List<BookModel> tutteLeOpere() => _catalogo;

  // Trova per id
  static BookModel? trovaPerId(String id) {
    try {
      return _catalogo.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  // Trova per nome ML - confronto parziale
  static BookModel trovaPerNomeML(String nomeML) {
    try {
      return _catalogo.firstWhere(
        (o) => nomeML.contains(o.titolo.split(' ').first),
      );
    } catch (_) {
      return _catalogo.first; // fallback
    }
  }
}
