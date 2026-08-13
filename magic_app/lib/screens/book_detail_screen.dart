import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/media_service.dart';
import '../widgets/audio_widget.dart';
import '../widgets/image_widget.dart';
import '../widgets/pdf_widget.dart';
import '../widgets/text_widget.dart';
import '../widgets/video_widget.dart';

// ==========================================
// SCHERMATA
// ==========================================

class BookDetailScreen extends StatefulWidget {
  final BookModel book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  MediaItem? _audioInEsecuzione;
  bool _audioMinimizzato = false;

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: _buildAppBar(colorScheme),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BookHeaderCard(book: widget.book),

                const SizedBox(height: 16),

                _MultimediaSection(
                  book: widget.book,
                  audioInEsecuzione: _audioInEsecuzione,
                  onPlayAudio: (item) {
                    setState(() {
                      _audioInEsecuzione = item;
                      _audioMinimizzato = false;
                    });
                  },
                ),

                _StartARButton(book: widget.book),
              ],
            ),
          ),

          if (_audioInEsecuzione != null)
            AudioWidget(
              titolo: _audioInEsecuzione!.titolo,
              audioPath: _audioInEsecuzione!.url,
              isMinimized: _audioMinimizzato,
              onMinimizeToggle: () => setState(() => _audioMinimizzato = true),
              onClose: () => setState(() => _audioInEsecuzione = null),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme colorScheme) {
    return AppBar(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      title: const Text(
        'Dettaglio',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ==========================================
// WIDGET
// ==========================================

// --- INTESTAZIONE LIBRO ---
class _BookHeaderCard extends StatelessWidget {
  final BookModel book;

  const _BookHeaderCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
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
    );
  }
}

// --- SEZIONE MULTIMEDIALE ---
class _MultimediaSection extends StatelessWidget {
  final BookModel book;
  final MediaItem? audioInEsecuzione;
  final ValueChanged<MediaItem> onPlayAudio;

  const _MultimediaSection({
    required this.book,
    required this.audioInEsecuzione,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    if (book.multimedia.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: _EmptyMediaCard(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contenuti multimediali',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        ...book.multimedia.map((media) {
          return _MediaListItem(
            media: media,
            allMedia: book.multimedia,
            audioInEsecuzione: audioInEsecuzione,
            onPlayAudio: onPlayAudio,
          );
        }),

        const SizedBox(height: 16),
      ],
    );
  }
}

// --- ITEM ELEMENTO MULTIMEDIALE ---
class _MediaListItem extends StatelessWidget {
  final MediaItem media;
  final List<MediaItem> allMedia;
  final MediaItem? audioInEsecuzione;
  final ValueChanged<MediaItem> onPlayAudio;

  const _MediaListItem({
    required this.media,
    required this.allMedia,
    required this.audioInEsecuzione,
    required this.onPlayAudio,
  });

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
      case 'testo':
        return Icons.article_outlined;
      case 'link_esterno':
        return Icons.open_in_new;
      default:
        return Icons.link;
    }
  }

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
      case 'testo':
        return Colors.brown;
      case 'link_esterno':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAudioActive = media.tipo == 'audio' && audioInEsecuzione == media;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _colorePerTipo(media.tipo).withValues(alpha: 0.15),
          child: Icon(
            isAudioActive ? Icons.graphic_eq : _iconaPerTipo(media.tipo),
            color: _colorePerTipo(media.tipo),
          ),
        ),
        title: Text(
          media.titolo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: media.descrizione.isNotEmpty ? Text(media.descrizione) : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () {
          switch (media.tipo) {
            case 'audio':
              onPlayAudio(media);
              break;
            case 'video':
              showDialog(
                context: context,
                builder: (_) =>
                    VideoDialog(titolo: media.titolo, videoPath: media.url),
              );
              break;
            case 'pdf':
              showDialog(
                context: context,
                useSafeArea: false,
                builder: (_) =>
                    PdfDialog(titolo: media.titolo, pdfPath: media.url),
              );
              break;
            case 'testo':
              showDialog(
                context: context,
                builder: (_) =>
                    TextDialog(titolo: media.titolo, textPath: media.url),
              );
              break;
            case 'immagine':
              final immaginiList = allMedia
                  .where((m) => m.tipo == 'immagine')
                  .toList();
              final imgIndex = immaginiList.indexOf(media);
              showDialog(
                context: context,
                builder: (_) => ImageDialog(
                  immagini: immaginiList,
                  initialIndex: imgIndex >= 0 ? imgIndex : 0,
                ),
              );
              break;
            case 'link_esterno':
            default:
              context.read<MediaService>().apriUrl(media.url);
              break;
          }
        },
      ),
    );
  }
}

// --- CARD VUOTA ---
class _EmptyMediaCard extends StatelessWidget {
  const _EmptyMediaCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),

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
    );
  }
}

// --- PULSANTE AR ---
class _StartARButton extends StatelessWidget {
  final BookModel book;

  const _StartARButton({required this.book});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          context.read<AppState>().selezionaOpera(book);
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
    );
  }
}
