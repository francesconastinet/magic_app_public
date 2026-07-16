// import 'main.dart';

// class OperaRepository {
//   static const List<Book> _catalogo = [
//     Opera(
//       id: '001',
//       titolo: 'Manoscritto Girolamini',
//       autore: 'Autore Ignoto',
//       biblioteca: 'Biblioteca dei Girolamini, Napoli',
//       periodo: 'Sec. XIV-XVII',
//       supporto: 'Pergamena',
//     ),
//     Opera(
//       id: '002',
//       titolo: 'Codice Miniato',
//       autore: 'Scuola Napoletana',
//       biblioteca: 'Biblioteca dei Girolamini, Napoli',
//       periodo: 'Sec. XV',
//       supporto: 'Pergamena miniata',
//     ),
//     Opera(
//       id: '003',
//       titolo: 'Antifonario',
//       autore: 'Anonimo sec. XIV',
//       biblioteca: 'Biblioteca dei Girolamini, Napoli',
//       periodo: 'Sec. XIV',
//       supporto: 'Pergamena',
//     ),
//   ];
//
//   // Restituisce tutte le opere
//   static List<Opera> tutteLeOpere() => _catalogo;
//
//   // Trova per id
//   static Opera? trovaPerId(String id) {
//     try {
//       return _catalogo.firstWhere((o) => o.id == id);
//     } catch (_) {
//       return null;
//     }
//   }
//
//   // Trova per nome ML (confronto parziale)
//   static Opera trovaPerNomeML(String nomeML) {
//     try {
//       return _catalogo.firstWhere(
//         (o) => nomeML.contains(o.titolo.split(' ').first),
//       );
//     } catch (_) {
//       return _catalogo.first; // fallback
//     }
//   }
// }

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
