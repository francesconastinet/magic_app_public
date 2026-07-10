import 'package:flutter/material.dart';
// import 'api_service.dart';
import 'models.dart';
import 'manuscript_screen.dart';
import 'package_service.dart';
import 'app_config.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: const Column(
          children: [
            Text('Collezioni',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Seleziona un percorso',
                style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: FutureBuilder<List<CollectionV2Model>>(
        // Legge le collezioni dal nuovo pacchetto invece che dal Gist
        future: PackageService().leggiCollezioniV2(AppConfig.packageId),
        builder: (context, snapshot) {
          // STATO LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Caricamento collezioni...'),
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
                  Text('Errore: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  const Text(
                    'Scarica prima il pacchetto dal bottone nuvola',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CollectionScreen()),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Riprova'),
                  ),
                ],
              ),
            );
          }

          // STATO PACCHETTO NON SCARICATO
          final collezioni = snapshot.data ?? [];
          if (collezioni.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_download_outlined,
                      size: 64,
                      color: colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'Nessuna collezione disponibile',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scarica il pacchetto premendo\nil bottone nuvola in Home',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13),
                  ),
                ],
              ),
            );
          }

          // STATO DATA — mostra le collezioni del pacchetto
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header pacchetto
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Biblioteca dei Girolamini',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${collezioni.length} collezioni disponibili',
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Lista collezioni dal nuovo pacchetto
              ...collezioni.map(
                (collection) => Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(Icons.collections_bookmark,
                          color: colorScheme.onPrimaryContainer),
                    ),
                    title: Text(collection.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    subtitle: collection.description.isNotEmpty
                        ? Text(collection.description)
                        : null,
                    trailing: Chip(
                      label: Text('${collection.bookIds.length} libri'),
                      backgroundColor: colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 12),
                    ),
                    onTap: () {
                      // Naviga alla lista libri della collezione
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManuscriptScreen(
                            packageId: AppConfig.packageId,
                            collectionId: collection.id,
                            collectionName: collection.name,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}