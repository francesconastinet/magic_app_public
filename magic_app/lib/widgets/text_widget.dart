import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/package_storage.dart';
import '../app_config.dart';

// ==========================================
// CONFIGURAZIONE LAYOUT
// ==========================================

class TextLayout {
  final Size screenSize;
  final bool isTablet;

  TextLayout(BuildContext context)
    : screenSize = MediaQuery.sizeOf(context),
      isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

  double get _sS => screenSize.shortestSide;

  // --- DIMENSIONI SCHERMATA ---
  double get borderRadius => _sS * (isTablet ? 0.02 : 0.04);
  double get headerFontSize => _sS * (isTablet ? 0.03 : 0.045);
  double get closeIconSize => _sS * (isTablet ? 0.04 : 0.06);
  double get contentFontSize => _sS * (isTablet ? 0.026 : 0.04);
  double get loaderHeight => _sS * 0.25;
}

// ==========================================
// SCHERMATA
// ==========================================

class TextWidget extends StatelessWidget {
  final String titolo;
  final String textPath;

  const TextWidget({super.key, required this.titolo, required this.textPath});

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final layout = TextLayout(context);

    return AlertDialog(
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(layout.borderRadius),
      ),
      title: TextDialogHeader(
        titolo: titolo,
        layout: layout,
        onClose: () => Navigator.pop(context),
      ),
      content: TextDialogContent(
        futureText: _inizializzaTesto(context),
        textPath: textPath,
        layout: layout,
      ),
    );
  }

  // --- LOGICA ---
  Future<String?> _inizializzaTesto(BuildContext context) async {
    try {
      // CASO 1: Modalità Test (File negli asset)
      // TODO: rimuovere quando il client sarà collegato al backend
      if (textPath.startsWith('assets/')) {
        return await rootBundle.loadString(textPath);
      }
      // CASO 2: Modalità Produzione (File estratti su disco dallo ZIP)
      else {
        final storageService = context.read<PackageStorage>();
        return await storageService.leggiFile(AppConfig.packageId, textPath);
      }
    } catch (e) {
      debugPrint('Errore lettura file testo: $e');
      return null;
    }
  }
}

// ==========================================
// WIDGET ESTRATTI
// ==========================================

// --- HEADER ---
class TextDialogHeader extends StatelessWidget {
  final String titolo;
  final VoidCallback onClose;
  final TextLayout layout;

  const TextDialogHeader({
    super.key,
    required this.titolo,
    required this.onClose,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titolo,
            style: TextStyle(
              color: Colors.white,
              fontSize: layout.headerFontSize,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        IconButton(
          icon: Icon(
            Icons.close,
            color: Colors.white,
            size: layout.closeIconSize,
          ),
          onPressed: onClose,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

// --- CONTENUTO TESTO ---
class TextDialogContent extends StatelessWidget {
  final Future<String?> futureText;
  final String textPath;
  final TextLayout layout;

  const TextDialogContent({
    super.key,
    required this.futureText,
    required this.textPath,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: futureText,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: layout.loaderHeight,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return SingleChildScrollView(
            child: Text(
              'Impossibile caricare il testo.\nPercorso cercato: $textPath',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: layout.contentFontSize,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: Text(
            snapshot.data!,
            style: TextStyle(
              color: Colors.white70,
              fontSize: layout.contentFontSize,
            ),
          ),
        );
      },
    );
  }
}
