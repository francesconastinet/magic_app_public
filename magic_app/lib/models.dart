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

// Singolo link multimediale nel books.json
class MediaItem {
  final String tipo;
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
    return MediaItem(
      tipo: json['tipo']?.toString() ?? '',
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
    final id = json['collection_id']?.toString() ??
        json['id']?.toString() ?? '';
    final name = json['nome']?.toString() ??
        json['name']?.toString() ?? '';
    final description = json['descrizione']?.toString() ??
        json['description']?.toString() ?? '';

    // Estrae gli id dai libri — supporta sia lista di oggetti che lista di stringhe
    final libriRaw = json['libri'] as List? ?? json['books'] as List? ?? [];
    final bookIds = libriRaw.map((e) {
      if (e is Map) {
        return e['id']?.toString() ?? '';
      }
      return e.toString();
    }).where((id) => id.isNotEmpty).toList();

    return CollectionV2Model(
      id: id,
      name: name,
      description: description,
      bookIds: bookIds,
    );
  }
}