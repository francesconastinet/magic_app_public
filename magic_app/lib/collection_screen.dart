import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models.dart';
import 'manuscript_screen.dart';

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
      body: FutureBuilder<PackageManifest>(
        future: ApiService().scaricaManifest(),
        builder: (context, snapshot) {
          // STATO LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scaricamento collezioni...'),
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

          // STATO DATA
          final manifest = snapshot.data!;
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
                      Text(manifest.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Versione ${manifest.version}',
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(manifest.description,
                          style: TextStyle(
                              color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Lista collezioni — navigazione a ManuscriptScreen
              ...manifest.collections.map(
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
                    subtitle: Text(collection.description),
                    trailing: Chip(
                      label: Text('${collection.manuscriptCount} ms'),
                      backgroundColor: colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 12),
                    ),
                    onTap: () {
                      // Naviga alla lista manoscritti del pacchetto
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManuscriptScreen(
                            packageId: 'magic_package_v1',
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