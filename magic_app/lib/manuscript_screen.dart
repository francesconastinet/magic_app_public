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
            const Text('Manoscritti',
                style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: FutureBuilder<List<ManuscriptModel>>(
        future: _caricaManoscritti(),
        builder: (context, snapshot) {
          // STATO LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Caricamento manoscritti...'),
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
          final manoscritti = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: manoscritti.length,
            itemBuilder: (context, index) {
              final ms = manoscritti[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      ms.id.replaceAll('ms', ''),
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(ms.titolo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(ms.autore),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(ms.periodo,
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Icon(Icons.arrow_forward_ios,
                          size: 14, color: colorScheme.primary),
                    ],
                  ),
                  onTap: () {
                    // Converte ManuscriptModel in Opera e salva in AppState
                    final opera = Opera(
                      id: ms.id,
                      titolo: ms.titolo,
                      autore: ms.autore,
                      biblioteca: ms.biblioteca,
                      periodo: ms.periodo,
                      supporto: ms.supporto,
                    );
                    context.read<AppState>().selezionaOpera(opera);
                    // Naviga alla schermata AR con i dati del manoscritto
                    context.push('/ar/${ms.titolo}');
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