import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../data/models.dart';

class MediaService {
  // Apre un MediaItem nel modo corretto in base al tipo
  Future<bool> apriMedia(MediaItem media) async {
    final uri = Uri.parse(media.url);
    return await _apriUrl(uri, media.tipo);
  }

  // Apre un URL generico
  Future<bool> apriUrl(String url) async {
    final uri = Uri.parse(url);
    return await _apriUrl(uri, MediaType.linkEsterno);
  }

  Future<bool> _apriUrl(Uri uri, MediaType tipo) async {
    try {
      // video e audio — prova prima app nativa (YouTube, Spotify ecc.)
      // poi fallback al browser
      if (tipo == MediaType.video || tipo == MediaType.audio) {
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      // pdf, immagine, link_esterno, testo — apre nel browser interno
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }

      debugPrint('Impossibile aprire URL: $uri');
      return false;
    } catch (e) {
      debugPrint('Errore apertura URL: $e');
      return false;
    }
  }

  // Restituisce etichetta leggibile per il tipo
  String etichettaTipo(MediaType tipo) {
    switch (tipo) {
      case MediaType.video:
        return 'Video';
      case MediaType.audio:
        return 'Audio';
      case MediaType.immagine:
        return 'Immagine';
      case MediaType.pdf:
        return 'PDF';
      case MediaType.testo:
        return 'Testo';
      case MediaType.linkEsterno:
        return 'Link esterno';
    }
  }
}
