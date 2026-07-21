import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../package_storage.dart';
import '../models.dart';

// ==========================================
// FINESTRA DI DIALOGO
// ==========================================

class ImageDialog extends StatefulWidget {
  final List<MediaItem> immagini;
  final int initialIndex;

  const ImageDialog({
    super.key,
    required this.immagini,
    required this.initialIndex,
  });

  @override
  State<ImageDialog> createState() => _ImageDialogState();
}

class _ImageDialogState extends State<ImageDialog> {
  late PageController _pageController;
  late int _currentIndex;

  // --- INIZIALIZZAZIONE ---
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final currentImage = widget.immagini[_currentIndex];
    final totalCount = widget.immagini.length;

    final screenSize = MediaQuery.sizeOf(context);
    final isTablet = screenSize.shortestSide >= 600;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final double adaptiveMaxWidth = isTablet
        ? screenSize.width * 0.8
        : (isLandscape ? screenSize.width * 0.7 : screenSize.width * 0.9);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: adaptiveMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImageDialogHeader(
              currentImage: currentImage,
              currentIndex: _currentIndex,
              totalCount: totalCount,
            ),
            ImageCarousel(
              pageController: _pageController,
              immagini: widget.immagini,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              imageBuilder: _buildImage,
            ),
            if (totalCount > 1)
              ImageDotsIndicator(
                currentIndex: _currentIndex,
                totalCount: totalCount,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, String imagePath) {
    // CASO 1: File negli asset (Modalità Mock/Test)
    // TODO: rimuovere quando il client sarà collegato al backend
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, color: Colors.white, size: 50),
      );
    }
    // CASO 2: File nel sistema (Scaricato dallo ZIP)
    else {
      final storageService = context.read<PackageStorage>();

      return FutureBuilder<String>(
        future: storageService.percorsoPacchetto(AppConfig.packageId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Icon(Icons.error, color: Colors.red, size: 50);
          }

          final percorsoAssoluto = '${snapshot.data}/$imagePath';

          return Image.file(
            File(percorsoAssoluto),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image, color: Colors.white, size: 50),
          );
        },
      );
    }
  }
}

// ==========================================
// WIDGET
// ==========================================

// --- HEADER ---
class ImageDialogHeader extends StatelessWidget {
  final MediaItem currentImage;
  final int currentIndex;
  final int totalCount;

  const ImageDialogHeader({
    super.key,
    required this.currentImage,
    required this.currentIndex,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${currentImage.titolo} (${currentIndex + 1}/$totalCount)',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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
    );
  }
}

// --- CAROSELLO ---
class ImageCarousel extends StatelessWidget {
  final PageController pageController;
  final List<MediaItem> immagini;
  final ValueChanged<int> onPageChanged;
  final Widget Function(BuildContext, String) imageBuilder;

  const ImageCarousel({
    super.key,
    required this.pageController,
    required this.immagini,
    required this.onPageChanged,
    required this.imageBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        child: Container(
          color: Colors.black,
          child: PageView.builder(
            controller: pageController,
            itemCount: immagini.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                child: imageBuilder(context, immagini[index].url),
              );
            },
          ),
        ),
      ),
    );
  }
}

// --- INDICATORI SCORRIMENTO ---
class ImageDotsIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalCount;

  const ImageDotsIndicator({
    super.key,
    required this.currentIndex,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          totalCount,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: currentIndex == index ? Colors.blueAccent : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }
}
