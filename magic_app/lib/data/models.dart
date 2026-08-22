// --- MODELLI DATI ---

class CollectionInfo {
  final String id;
  final String name;
  final String description;
  final int manuscriptCount;

  CollectionInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.manuscriptCount,
  });

  factory CollectionInfo.fromJson(Map<String, dynamic> json) {
    return CollectionInfo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      manuscriptCount: json['manuscriptCount'] as int? ?? 0,
    );
  }
}

class PackageManifest {
  final String version;
  final String name;
  final String description;
  final List<CollectionInfo> collections;
  final String packageUrl;

  PackageManifest({
    required this.version,
    required this.name,
    required this.description,
    required this.collections,
    required this.packageUrl,
  });

  factory PackageManifest.fromJson(Map<String, dynamic> json) {
    return PackageManifest(
      version: json['version']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      packageUrl: json['packageUrl']?.toString() ?? '',
      collections: (json['collections'] as List? ?? [])
          .map((c) => CollectionInfo.fromJson(c))
          .toList(),
    );
  }
}

class ManuscriptModel {
  final String id;
  final String titolo;
  final String autore;
  final String periodo;
  final String supporto;
  final String biblioteca;

  ManuscriptModel({
    required this.id,
    required this.titolo,
    required this.autore,
    required this.periodo,
    required this.supporto,
    required this.biblioteca,
  });

  factory ManuscriptModel.fromJson(Map<String, dynamic> json) {
    return ManuscriptModel(
      id: json['id']?.toString() ?? '',
      titolo: json['titolo']?.toString() ?? '',
      autore: json['autore']?.toString() ?? '',
      periodo: json['periodo']?.toString() ?? '',
      supporto: json['supporto']?.toString() ?? '',
      biblioteca: json['biblioteca']?.toString() ?? '',
    );
  }
}

class CollectionModel {
  final String id;
  final String name;
  final String description;
  final List<String> manuscriptIds;

  CollectionModel({
    required this.id,
    required this.name,
    required this.description,
    required this.manuscriptIds,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    return CollectionModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      manuscriptIds: (json['manuscripts'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

// --- MODELLI NUOVA STRUTTURA PACCHETTO  ---

enum MediaType { video, audio, immagine, pdf, testo, linkEsterno }

String getTitoloTipo(MediaType tipo) {
  switch (tipo) {
    case MediaType.video:
      return 'Video';
    case MediaType.audio:
      return 'Audio';
    case MediaType.immagine:
      return 'Immagini';
    case MediaType.pdf:
      return 'PDF';
    case MediaType.testo:
      return 'Testi';
    case MediaType.linkEsterno:
      return 'Link';
  }
}

// Singolo link multimediale nel books.json
class MediaItem {
  final MediaType tipo;
  final String titolo;
  final String url;
  final String descrizione;

  MediaItem({
    required this.tipo,
    required this.titolo,
    required this.url,
    required this.descrizione,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final tipoString = json['tipo']?.toString().toLowerCase() ?? '';

    MediaType parsedTipo;
    switch (tipoString) {
      case 'video':
        parsedTipo = MediaType.video;
        break;
      case 'audio':
        parsedTipo = MediaType.audio;
        break;
      case 'immagine':
        parsedTipo = MediaType.immagine;
        break;
      case 'pdf':
        parsedTipo = MediaType.pdf;
        break;
      case 'testo':
        parsedTipo = MediaType.testo;
        break;
      case 'link_esterno':
      default:
        parsedTipo = MediaType.linkEsterno;
        break;
    }

    return MediaItem(
      tipo: parsedTipo,
      titolo: json['titolo']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      descrizione: json['descrizione']?.toString() ?? '',
    );
  }
}

// Libro dalla nuova struttura  books.json
class BookModel {
  final String id;
  final String titolo;
  final String autore;
  final String anno;
  final List<MediaItem> multimedia;

  BookModel({
    required this.id,
    required this.titolo,
    required this.autore,
    required this.anno,
    required this.multimedia,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id']?.toString() ?? '',
      titolo: json['titolo']?.toString() ?? '',
      autore: json['autore']?.toString() ?? '',
      anno: json['anno']?.toString() ?? '',
      multimedia: (json['multimedia'] as List? ?? [])
          .map((m) => MediaItem.fromJson(m))
          .toList(),
    );
  }
}

// Collezione dalla struttura collections.json della nuova struttura
// Campi reali: collection_id, nome, libri (lista di oggetti {id, titolo})
class CollectionV2Model {
  final String id;
  final String name;
  final String description;
  final List<String> bookIds;

  CollectionV2Model({
    required this.id,
    required this.name,
    required this.description,
    required this.bookIds,
  });

  factory CollectionV2Model.fromJson(Map<String, dynamic> json) {
    // La struttura usa "collection_id" invece di "id"
    // e "nome" invece di "name"
    // e "libri" invece di "books" — con oggetti {id, titolo} invece di stringhe
    final id =
        json['collection_id']?.toString() ?? json['id']?.toString() ?? '';
    final name = json['nome']?.toString() ?? json['name']?.toString() ?? '';
    final description =
        json['descrizione']?.toString() ??
        json['description']?.toString() ??
        '';

    // Estrae gli id dai libri — supporta sia lista di oggetti che lista di stringhe
    final libriRaw = json['libri'] as List? ?? json['books'] as List? ?? [];
    final bookIds = libriRaw
        .map((e) {
          if (e is Map) {
            return e['id']?.toString() ?? '';
          }
          return e.toString();
        })
        .where((id) => id.isNotEmpty)
        .toList();

    return CollectionV2Model(
      id: id,
      name: name,
      description: description,
      bookIds: bookIds,
    );
  }
}
