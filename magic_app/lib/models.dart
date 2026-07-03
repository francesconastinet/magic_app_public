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
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      manuscriptCount: json['manuscriptCount'] as int,
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
      version: json['version'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      packageUrl: json['packageUrl'] as String? ?? '',
      collections: (json['collections'] as List)
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
      id: json['id'] as String,
      titolo: json['titolo'] as String,
      autore: json['autore'] as String,
      periodo: json['periodo'] as String,
      supporto: json['supporto'] as String,
      biblioteca: json['biblioteca'] as String,
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
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      manuscriptIds: List<String>.from(json['manuscripts'] as List),
    );
  }
}

// --- MODELLI NUOVA STRUTTURA PACCHETTO ---

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
      tipo: json['tipo'] as String,
      titolo: json['titolo'] as String,
      url: json['url'] as String,
      descrizione: json['descrizione'] as String? ?? '',
    );
  }
}

// Libro dalla nuova struttura books.json
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
      id: json['id'] as String,
      titolo: json['titolo'] as String,
      autore: json['autore'] as String,
      anno: json['anno'] as String? ?? '',
      multimedia: (json['multimedia'] as List? ?? [])
          .map((m) => MediaItem.fromJson(m))
          .toList(),
    );
  }
}

// Collezione dalla nuova struttura collections.json
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
    return CollectionV2Model(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      bookIds: List<String>.from(json['books'] as List? ?? []),
    );
  }
}