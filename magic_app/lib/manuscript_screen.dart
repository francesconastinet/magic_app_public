import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package_service.dart';
import 'package_storage.dart';
import 'auth_service.dart';
import 'models.dart';
import 'book_detail_screen.dart';

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
    final collectionData =
        await service.leggiCollection(packageId, collectionId);
    if (collectionData == null) throw Exception('Collezione non trovata');
    final collection = CollectionModel.fromJson(collectionData);
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
  // MODIFICATO — prende BuildContext per poter leggere le dipendenze dal
  // Provider (context.read va chiamato PRIMA di qualsiasi await, quindi
  // il context va passato come parametro invece di usare quello del widget
  // in un momento successivo dell'esecuzione async)
  Future<List<BookModel>> _caricaLibri(BuildContext context) async {
    final service = PackageService(
      storage: context.read<PackageStorage>(),
      authService: context.read<AuthService>(),
    );
    // Legge i libri della collezione dalla nuova struttura
    final libri = await service.leggiLibriDiCollezione(packageId, collectionId);
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
            Text(
              collectionName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text('Libri', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: FutureBuilder<List<BookModel>>(
        // MODIFICATO — passa il context corrente al metodo
        future: _caricaLibri(context),
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
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    book.titolo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(book.autore),
                  // Anno nel trailing con Expanded per evitare overflow
                  trailing: book.anno.isNotEmpty
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 80),
                          child: Text(
                            book.anno,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        )
                      : Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                  onTap: () {
                    // Naviga al dettaglio libro invece di andare direttamente in AR
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookDetailScreen(book: book),
                      ),
                    );
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
