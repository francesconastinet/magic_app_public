import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../package_storage.dart';
import '../app_config.dart';

class TextDialog extends StatelessWidget {
  final String titolo;
  final String textPath;

  const TextDialog({
    super.key,
    required this.titolo,
    required this.textPath,
  });

  Future<String?> _leggiTestoSmart(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

      title: Row(
        children: [
          Expanded(
            child: Text(
              titolo,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),

      content: FutureBuilder<String?>(
        future: _leggiTestoSmart(context),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return SingleChildScrollView(
              child: Text(
                'Impossibile caricare il testo.\nPercorso cercato: $textPath',
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 16),
              ),
            );
          }

          return SingleChildScrollView(
            child: Text(
              snapshot.data!, // Contenuto del file
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          );
        },
      ),
    );
  }
}
