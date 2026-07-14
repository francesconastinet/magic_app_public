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

  // Funzione che decide da dove leggere il file
  Future<String?> _leggiTesto(BuildContext context) async {
    try {
      // CASO 1: Modalità Test (File negli asset)
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
      title: Text(titolo, style: const TextStyle(color: Colors.white)),

      content: FutureBuilder<String?>(
        future: _leggiTesto(context),
        builder: (context, snapshot) {

          // Stato di caricamento
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          // Gestione errori
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return SingleChildScrollView(
              child: Text(
                'Impossibile caricare il testo.\nPercorso cercato: $textPath',
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 16),
              ),
            );
          }

          // Stampiamo il contenuto del file
          return SingleChildScrollView(
            child: Text(
              snapshot.data!,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi', style: TextStyle(color: Colors.blueAccent)),
        ),
      ],
    );
  }
}