import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../package_storage.dart';

class PdfDialog extends StatefulWidget {
  final String titolo;
  final String pdfPath;

  const PdfDialog({
    super.key,
    required this.titolo,
    required this.pdfPath,
  });

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

  Future<void> _inizializzaPdf() async {
    try {
      // CASO 1: File negli asset (Modalità Test)
      // TODO: rimuovere quando il client sarà collegato al backend
      if (widget.pdfPath.startsWith('assets/')) {
        // Legge i byte dal bundle dell'app
        final byteData = await rootBundle.load(widget.pdfPath);
        final fileBytes = byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes);

        // Trova la cartella temporanea del dispositivo
        final tempDir = await getTemporaryDirectory();

        // Estrae il nome del file e lo salva temporaneamente
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
        final basePath = await storageService.percorsoPacchetto(AppConfig.packageId);

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

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black87,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
            color: Colors.black,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.titolo,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isReady && _percorsoAssoluto != null)
                  Text(
                    '${_currentPage! + 1}/$_totalPages',
                    style: const TextStyle(color: Colors.white54),
                  ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildPdfContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfContent() {
    if (_hasError) {
      return const Center(
        child: Text(
          'Impossibile caricare il documento PDF.',
          style: TextStyle(color: Colors.redAccent, fontSize: 16),
        ),
      );
    }

    if (_percorsoAssoluto == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        PDFView(
          filePath: _percorsoAssoluto!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: false,
          pageFling: true,
          onRender: (pages) {
            setState(() {
              _totalPages = pages;
              _isReady = true;
            });
          },
          onPageChanged: (int? page, int? total) {
            setState(() {
              _currentPage = page;
            });
          },
          onError: (error) {
            debugPrint('Errore rendering PDFView: $error');
            setState(() => _hasError = true);
          },
          onPageError: (page, error) {
            debugPrint('Errore rendering pagina $page: $error');
          },
        ),

        if (!_isReady)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}