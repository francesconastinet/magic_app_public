import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../package_storage.dart';

class ImageDialog extends StatelessWidget {
  final String titolo;
  final String imagePath;

  const ImageDialog({
    super.key,
    required this.titolo,
    required this.imagePath,
  });

  Widget _buildImage(BuildContext context) {
    // CASO 1: File negli asset (Modalità Mock/Test)
    // TODO: rimuovere quando il client sarà collegato al backend
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.broken_image,
            color: Colors.white,
            size: 50),
      );
    }

    // CASO 2: File nel sistema (Scaricato dallo ZIP)
    else {
      final storageService = context.read<PackageStorage>();

      return FutureBuilder<String>(
        future: storageService.percorsoPacchetto(AppConfig.packageId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Icon(Icons.error, color: Colors.red, size: 50);
          }

          final percorsoAssoluto = '${snapshot.data}/$imagePath';

          return Image.file(
            File(percorsoAssoluto),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image,
                color: Colors.white,
                size: 50),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    titolo,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildImage(context),
          ),
        ],
      ),
    );
  }
}