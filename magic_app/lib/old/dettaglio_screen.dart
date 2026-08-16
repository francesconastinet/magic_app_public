import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../core/app_state.dart';

class DettaglioScreen extends StatelessWidget {
  final String id;
  const DettaglioScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: Text('Opera $id'),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final opera = appState.operaSelezionata;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                CircleAvatar(
                  radius: 48,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.menu_book,
                    size: 48,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  opera?.titolo ?? 'Opera $id',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  opera?.autore ?? '',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 24),

                if (opera != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _infoRiga(
                            context,
                            'Biblioteca',
                            'Biblioteca dei Girolamini',
                          ),

                          const Divider(),

                          _infoRiga(context, 'Anno', opera.anno),

                          const Divider(),

                          _infoRiga(context, 'Supporto', 'Carta'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modello 3D',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 250,
                          child: ModelViewer(
                            src:
                                'https://modelviewer.dev/shared-assets/models/Astronaut.glb',
                            alt: 'Modello 3D opera',
                            ar: false,
                            autoRotate: true,
                            cameraControls: true,
                            backgroundColor: const Color(0xFFF5F0E8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Placeholder — modello 3D definitivo da caricare',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                if (appState.ultimaOpera != null)
                  Chip(
                    avatar: const Icon(Icons.check_circle, size: 18),
                    label: Text('Ultima vista: ${appState.ultimaOpera}'),
                    backgroundColor: colorScheme.primaryContainer,
                  ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/ar/${opera?.titolo ?? id}'),
                    icon: const Icon(Icons.view_in_ar),
                    label: const Text('Avvia Realtà Aumentata'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRiga(BuildContext context, String label, String valore) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),

          Expanded(child: Text(valore, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
