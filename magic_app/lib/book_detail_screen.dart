import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'main.dart';
import 'media_service.dart';
import 'chat_screen.dart';
import 'audio_player_widget.dart';

class BookDetailScreen extends StatelessWidget {
  final BookModel book;

  const BookDetailScreen({super.key, required this.book});

  // Restituisce l'icona giusta per ogni tipo di multimedia
  IconData _iconaPerTipo(String tipo) {
    switch (tipo) {
      case 'video':
        return Icons.play_circle_outline;
      case 'audio':
        return Icons.headphones;
      case 'immagine':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'link_esterno':
        return Icons.open_in_new;
      default:
        return Icons.link;
    }
  }

  // Restituisce il colore per ogni tipo di multimedia
  Color _colorePerTipo(String tipo) {
    switch (tipo) {
      case 'video':
        return Colors.red;
      case 'audio':
        return Colors.purple;
      case 'immagine':
        return Colors.blue;
      case 'pdf':
        return Colors.orange;
      case 'link_esterno':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // MediaService per aprire i link multimediali
    final mediaService = MediaService();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: const Text(
          'Dettaglio',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Bottone Assistente Virtuale
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Assistente Virtuale',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text('Chat')),
                    body: ChatWidget(
                      contestoAttivoNome: book.titolo,
                      bookIds: [book.id],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header libro — layout compatto per evitare overflow
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(
                            Icons.menu_book,
                            size: 24,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            book.titolo,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      book.autore,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.anno,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sezione multimedia
            if (book.multimedia.isNotEmpty) ...[
              Text(
                'Contenuti multimediali',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...book.multimedia.map((media) {
                // Audio riprodotto in-app con AudioPlayerWidget
                if (media.tipo == 'audio') {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AudioPlayerWidget(media: media),
                  );
                }
                // Altri tipi — apertura con url_launcher
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _colorePerTipo(
                        media.tipo,
                      ).withValues(alpha: 0.15),
                      child: Icon(
                        _iconaPerTipo(media.tipo),
                        color: _colorePerTipo(media.tipo),
                      ),
                    ),
                    title: Text(
                      media.titolo,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: media.descrizione.isNotEmpty
                        ? Text(media.descrizione)
                        : null,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      // Apre il link multimediale con MediaService
                      final aperto = await mediaService.apriMedia(media);
                      if (!aperto && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Impossibile aprire ${mediaService.etichettaTipo(media.tipo)}',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                );
              }),
              const SizedBox(height: 16),
            ] else ...[
              // Expanded nel Row per evitare overflow del testo
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nessun contenuto multimediale disponibile',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Bottone Avvia AR
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Converte BookModel in Opera e salva in AppState
                  // final opera = Opera(
                  //   id: book.id,
                  //   titolo: book.titolo,
                  //   autore: book.autore,
                  //   biblioteca: 'Biblioteca dei Girolamini',
                  //   periodo: book.anno,
                  //   supporto: '',
                  // );
                  context.read<AppState>().selezionaOpera(book);
                  // Naviga alla schermata AR
                  context.push('/ar/${book.titolo}');
                },
                icon: const Icon(Icons.view_in_ar),
                label: const Text('Avvia Realtà Aumentata'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
