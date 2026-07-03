import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package_service.dart';
import 'models.dart';
import 'main.dart';

class ManuscriptScreen extends StatelessWidget {
  final String packageId;
  final String collectionId;
  final String collectionName;

  const ManuscriptScreen({
    super.key,
    required this.packageId,
    required this.collectionId,
    required this.collectionName,
  });

  /* Vecchia struttura — mantenuta per retrocompatibilita'
  Future<List<ManuscriptModel>> _caricaManoscritti() async {
    final service = PackageService();

    // Legge collection.json per ottenere la lista degli id
    final collectionData =
        await service.leggiCollection(packageId, collectionId);
    if (collectionData == null) throw Exception('Collezione non trovata');

    final collection = CollectionModel.fromJson(collectionData);

    // Carica info.json di ogni manoscritto
    final manoscritti = <ManuscriptModel>[];
    for (final msId in collection.manuscriptIds) {
      final info =
          await service.leggiInfoManoscritto(packageId, collectionId, msId);
      if (info != null) {
        manoscritti.add(ManuscriptModel.fromJson(info));
      }
    }
    return manoscritti;
  }

  */

  // Nuova struttura — legge books.json e collections.json
  Future<List<BookModel>> _caricaLibri() async {
    final service = PackageService();
    // Legge i libri della collezione dalla nuova struttura
    final libri = await service.leggiLibriDiCollezione(
        packageId, collectionId);
    if (libri.isEmpty) throw Exception('Nessun libro trovato');
    return libri;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: Column(
          children: [
            Text(collectionName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Libri',
                style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: FutureBuilder<List<BookModel>>(
        future: _caricaLibri(),
        builder: (context, snapshot) {
          // STATO LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Caricamento libri...'),
                ],
              ),
            );
          }

          // STATO ERROR
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('${snapshot.error}'),
                  const SizedBox(height: 8),
                  const Text(
                    'Scarica prima il pacchetto dal bottone ZIP',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // STATO DATA
          final libri = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: libri.length,
            itemBuilder: (context, index) {
              final book = libri[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      book.id.replaceAll('book', ''),
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(book.titolo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(book.autore),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(book.anno,
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      // Icona multimedia se il libro ha contenuti
                      book.multimedia.isNotEmpty
                          ? Icon(Icons.play_circle_outline,
                              size: 14, color: colorScheme.primary)
                          : Icon(Icons.arrow_forward_ios,
                              size: 14, color: colorScheme.primary),
                    ],
                  ),
                  onTap: () {
                    // Converte BookModel in Opera e salva in AppState
                    final opera = Opera(
                      id: book.id,
                      titolo: book.titolo,
                      autore: book.autore,
                      biblioteca: 'Biblioteca dei Girolamini',
                      periodo: book.anno,
                      supporto: '',
                    );
                    context.read<AppState>().selezionaOpera(opera);
                    // Naviga alla schermata AR con i dati del libro
                    context.push('/ar/${book.titolo}');
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}