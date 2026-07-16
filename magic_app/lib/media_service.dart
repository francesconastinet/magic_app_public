import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'models.dart';

class MediaService {
  // Apre un MediaItem nel modo corretto in base al tipo
  Future<bool> apriMedia(MediaItem media) async {
    final uri = Uri.parse(media.url);
    return await _apriUrl(uri, media.tipo);
  }

  // Apre un URL generico
  Future<bool> apriUrl(String url) async {
    final uri = Uri.parse(url);
    return await _apriUrl(uri, 'link_esterno');
  }

  Future<bool> _apriUrl(Uri uri, String tipo) async {
    try {
      // video e audio — prova prima app nativa (YouTube, Spotify ecc.)
      // poi fallback al browser
      if (tipo == 'video' || tipo == 'audio') {
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      // pdf, immagine, link_esterno — apre nel browser interno
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
  String etichettaTipo(String tipo) {
    switch (tipo) {
      case 'video':
        return 'Video';
      case 'audio':
        return 'Audio';
      case 'immagine':
        return 'Immagine';
      case 'pdf':
        return 'PDF';
      case 'link_esterno':
        return 'Link esterno';
      default:
        return 'Contenuto';
    }
  }
}
