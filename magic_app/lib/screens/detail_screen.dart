import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../data/models.dart';
import '../services/media_service.dart';
import '../widgets/audio_widget.dart';
import '../widgets/image_widget.dart';
import '../widgets/pdf_widget.dart';
import '../widgets/text_widget.dart';
import '../widgets/video_widget.dart';

// ==========================================
// SCHERMATA
// ==========================================

class DetailScreen extends StatefulWidget {
  final BookModel book;

  const DetailScreen({super.key, required this.book});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  MediaItem? _audioInEsecuzione;
  bool _audioMinimizzato = false;

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Scaffold(appBar: _buildAppBar(colorScheme), body: _buildBody()),

          if (_audioInEsecuzione != null)
            SafeArea(
              child: AudioWidget(
                titolo: _audioInEsecuzione!.titolo,
                audioPath: _audioInEsecuzione!.url,
                isMinimized: _audioMinimizzato,
                onMinimizeToggle: () =>
                    setState(() => _audioMinimizzato = true),
                onClose: () => setState(() => _audioInEsecuzione = null),
              ),
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
      actions: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: 'Chiedi all\'Assistente',
          onPressed: () {
            context.read<AppState>().selezionaOpera(widget.book);
            context.go('/');
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
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
          ],
        ),
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

            const Divider(height: 24),

            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    book.autore,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    book.anno,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
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
    final mediaGrouped = <MediaType, List<MediaItem>>{};
    for (final m in book.multimedia) {
      mediaGrouped.putIfAbsent(m.tipo, () => []).add(m);
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
        const SizedBox(height: 12),

        if (book.multimedia.isEmpty)
          const _EmptyMediaCard()
        else ...[
          if (mediaGrouped.containsKey(MediaType.video))
            _buildGroup(
              'Video',
              Icons.videocam,
              Colors.red,
              mediaGrouped[MediaType.video]!,
            ),
          if (mediaGrouped.containsKey(MediaType.audio))
            _buildGroup(
              'Audio',
              Icons.audiotrack,
              Colors.purple,
              mediaGrouped[MediaType.audio]!,
            ),
          if (mediaGrouped.containsKey(MediaType.immagine))
            _buildGroup(
              'Immagini',
              Icons.image,
              Colors.blue,
              mediaGrouped[MediaType.immagine]!,
            ),
          if (mediaGrouped.containsKey(MediaType.pdf))
            _buildGroup(
              'PDF',
              Icons.picture_as_pdf,
              Colors.orange,
              mediaGrouped[MediaType.pdf]!,
            ),
          if (mediaGrouped.containsKey(MediaType.testo))
            _buildGroup(
              'Testi',
              Icons.article,
              Colors.brown,
              mediaGrouped[MediaType.testo]!,
            ),
          if (mediaGrouped.containsKey(MediaType.linkEsterno))
            _buildGroup(
              'Link',
              Icons.link,
              Colors.green,
              mediaGrouped[MediaType.linkEsterno]!,
            ),
        ],
      ],
    );
  }

  Widget _buildGroup(
    String titolo,
    IconData icona,
    Color colore,
    List<MediaItem> mediaList,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(icona, color: colore),
        title: Text(
          '$titolo (${mediaList.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: mediaList
            .map(
              (media) => _MediaListItem(
                media: media,
                allMedia: book.multimedia,
                audioInEsecuzione: audioInEsecuzione,
                onPlayAudio: onPlayAudio,
              ),
            )
            .toList(),
      ),
    );
  }
}

// --- ELEMENTO MULTIMEDIALE ---
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

  @override
  Widget build(BuildContext context) {
    final isAudioActive =
        media.tipo == MediaType.audio && audioInEsecuzione == media;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: Icon(
        isAudioActive ? Icons.volume_up : Icons.arrow_right,
        color: colorScheme.onSurfaceVariant,
        size: isAudioActive ? 20 : 24,
      ),
      title: Text(
        media.titolo,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isAudioActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        switch (media.tipo) {
          case MediaType.audio:
            onPlayAudio(media);
            break;

          case MediaType.video:
            showDialog(
              context: context,
              builder: (_) =>
                  VideoWidget(titolo: media.titolo, videoPath: media.url),
            );
            break;

          case MediaType.pdf:
            showDialog(
              context: context,
              useSafeArea: false,
              builder: (_) =>
                  PdfWidget(titolo: media.titolo, pdfPath: media.url),
            );
            break;

          case MediaType.testo:
            showDialog(
              context: context,
              builder: (_) =>
                  TextWidget(titolo: media.titolo, textPath: media.url),
            );
            break;

          case MediaType.immagine:
            final immaginiList = allMedia
                .where((m) => m.tipo == MediaType.immagine)
                .toList();
            final imgIndex = immaginiList.indexOf(media);
            showDialog(
              context: context,
              builder: (_) => ImageWidget(
                immagini: immaginiList,
                initialIndex: imgIndex >= 0 ? imgIndex : 0,
              ),
            );
            break;

          case MediaType.linkEsterno:
            context.read<MediaService>().apriUrl(media.url);
            break;
        }
      },
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
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          Icons.folder_off_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
        title: Text(
          'Nessun contenuto',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          'Non ci sono file multimediali disponibili.',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
        ),
      ),
    );
  }
}
