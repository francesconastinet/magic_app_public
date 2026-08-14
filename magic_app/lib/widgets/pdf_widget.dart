import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../app_config.dart';
import '../services/package_storage.dart';

// ==========================================
// CONFIGURAZIONE LAYOUT
// ==========================================

class PdfLayout {
  final Size screenSize;
  final bool isLandscape;
  final bool isTablet;

  PdfLayout(BuildContext context)
    : screenSize = MediaQuery.sizeOf(context),
      isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape,
      isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

  double get _sS => screenSize.shortestSide;
  double get _lS => screenSize.longestSide;

  // --- DIMENSIONI SCHERMATA ---
  double get maxPdfWidth {
    if (isTablet) {
      return (screenSize.width * 0.75).clamp(_lS * 0.5, _lS * 0.76);
    } else if (isLandscape) {
      return (screenSize.width * 0.55).clamp(_lS * 0.4, _lS * 0.65);
    }
    return double.infinity;
  }

  // --- MISURE TESTI E SPAZIATURE ---
  double get padding => _sS * 0.04;
  double get spacing => _sS * 0.04;
  double get titleFontSize => _sS * (isTablet ? 0.03 : 0.045);
  double get counterFontSize => _sS * (isTablet ? 0.03 : 0.035);
  double get iconSize => _sS * (isTablet ? 0.045 : 0.06);
  double get errorFontSize => _sS * 0.04;
}

// ==========================================
// SCHERMATA
// ==========================================

class PdfWidget extends StatefulWidget {
  final String titolo;
  final String pdfPath;

  const PdfWidget({super.key, required this.titolo, required this.pdfPath});

  @override
  State<PdfWidget> createState() => _PdfWidgetState();
}

class _PdfWidgetState extends State<PdfWidget> {
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

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final layout = PdfLayout(context);

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
              layout: layout,
              onClose: () => Navigator.pop(context),
            ),

            Expanded(
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: layout.maxPdfWidth),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.white,
                    child: PdfContentWidget(
                      hasError: _hasError,
                      percorsoAssoluto: _percorsoAssoluto,
                      layout: layout,
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

  // --- LOGICA ---
  Future<void> _inizializzaPdf() async {
    try {
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
      } else {
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
  final PdfLayout layout;
  final VoidCallback onClose;

  const PdfDialogHeader({
    super.key,
    required this.titolo,
    required this.currentPage,
    required this.totalPages,
    required this.isReady,
    required this.percorsoAssoluto,
    required this.layout,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(layout.padding),
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: Text(
              titolo,
              style: TextStyle(
                color: Colors.white,
                fontSize: layout.titleFontSize,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          if (isReady && percorsoAssoluto != null)
            Text(
              '${currentPage! + 1}/$totalPages',
              style: TextStyle(
                color: Colors.white54,
                fontSize: layout.counterFontSize,
              ),
            ),

          SizedBox(width: layout.spacing),

          IconButton(
            icon: Icon(Icons.close, color: Colors.white, size: layout.iconSize),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
  final PdfLayout layout;
  final bool isReady;
  final ValueChanged<int?> onRender;
  final ValueChanged<int?> onPageChanged;
  final VoidCallback onError;

  const PdfContentWidget({
    super.key,
    required this.hasError,
    required this.percorsoAssoluto,
    required this.layout,
    required this.isReady,
    required this.onRender,
    required this.onPageChanged,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Center(
        child: Text(
          'Impossibile caricare il documento PDF.',
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: layout.errorFontSize,
          ),
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
          fitPolicy: layout.isLandscape ? FitPolicy.WIDTH : FitPolicy.BOTH,
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
