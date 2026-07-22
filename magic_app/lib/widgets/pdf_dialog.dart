import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../package_storage.dart';

// ==========================================
// SCHERMATA WIDGET
// ==========================================

class PdfDialog extends StatefulWidget {
  final String titolo;
  final String pdfPath;

  const PdfDialog({super.key, required this.titolo, required this.pdfPath});

  @override
  State<PdfDialog> createState() => _PdfDialogState();
}

class _PdfDialogState extends State<PdfDialog> {
  int? _totalPages = 0;
  int? _currentPage = 0;
  bool _isReady = false;
  String? _percorsoAssoluto;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _inizializzaPdf();
  }

  // --- INIZIALIZZAZIONE ---
  Future<void> _inizializzaPdf() async {
    try {
      // CASO 1: File negli asset (Modalità Test)
      // TODO: rimuovere quando il client sarà collegato al backend
      if (widget.pdfPath.startsWith('assets/')) {
        final byteData = await rootBundle.load(widget.pdfPath);
        final fileBytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );

        final tempDir = await getTemporaryDirectory();
        final fileName = widget.pdfPath.split('/').last;
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(fileBytes);

        if (mounted) {
          setState(() {
            _percorsoAssoluto = tempFile.path;
          });
        }
      }
      // CASO 2: File nel sistema (Scaricato dallo ZIP)
      else {
        final storageService = context.read<PackageStorage>();
        final basePath = await storageService.percorsoPacchetto(
          AppConfig.packageId,
        );

        if (mounted) {
          setState(() {
            _percorsoAssoluto = '$basePath/${widget.pdfPath}';
          });
        }
      }
    } catch (e) {
      debugPrint('Errore inizializzazione PDF: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isTablet = screenSize.shortestSide >= 600;

    final double maxPdfWidth = isTablet
        ? (screenSize.width * 0.75).clamp(600.0, 900.0)
        : (isLandscape
              ? (screenSize.width * 0.55).clamp(350.0, 550.0)
              : double.infinity);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            PdfDialogHeader(
              titolo: widget.titolo,
              currentPage: _currentPage,
              totalPages: _totalPages,
              isReady: _isReady,
              percorsoAssoluto: _percorsoAssoluto,
              onClose: () => Navigator.pop(context),
            ),
            Expanded(
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxPdfWidth),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.white,
                    child: PdfContentWidget(
                      hasError: _hasError,
                      percorsoAssoluto: _percorsoAssoluto,
                      isLandscape: isLandscape,
                      isReady: _isReady,
                      onRender: (pages) {
                        setState(() {
                          _totalPages = pages;
                          _isReady = true;
                        });
                      },
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      onError: () {
                        setState(() => _hasError = true);
                      },
                    ),
                  ),
                ),
              ),
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

// --- HEADER ---
class PdfDialogHeader extends StatelessWidget {
  final String titolo;
  final int? currentPage;
  final int? totalPages;
  final bool isReady;
  final String? percorsoAssoluto;
  final VoidCallback onClose;

  const PdfDialogHeader({
    super.key,
    required this.titolo,
    required this.currentPage,
    required this.totalPages,
    required this.isReady,
    required this.percorsoAssoluto,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: Text(
              titolo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isReady && percorsoAssoluto != null)
            Text(
              '${currentPage! + 1}/$totalPages',
              style: const TextStyle(color: Colors.white54),
            ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

// --- CONTENUTO PDF ---
class PdfContentWidget extends StatelessWidget {
  final bool hasError;
  final String? percorsoAssoluto;
  final bool isLandscape;
  final bool isReady;
  final ValueChanged<int?> onRender;
  final ValueChanged<int?> onPageChanged;
  final VoidCallback onError;

  const PdfContentWidget({
    super.key,
    required this.hasError,
    required this.percorsoAssoluto,
    required this.isLandscape,
    required this.isReady,
    required this.onRender,
    required this.onPageChanged,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return const Center(
        child: Text(
          'Impossibile caricare il documento PDF.',
          style: TextStyle(color: Colors.redAccent, fontSize: 16),
        ),
      );
    }

    if (percorsoAssoluto == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PDFView(
          filePath: percorsoAssoluto!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          fitEachPage: true,
          fitPolicy: isLandscape ? FitPolicy.WIDTH : FitPolicy.BOTH,
          onRender: onRender,
          onPageChanged: (int? page, int? total) => onPageChanged(page),
          onError: (error) {
            debugPrint('Errore rendering PDFView: $error');
            onError();
          },
          onPageError: (page, error) {
            debugPrint('Errore rendering pagina $page: $error');
          },
        ),
        if (!isReady) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
