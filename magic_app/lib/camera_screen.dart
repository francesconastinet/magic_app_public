import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_state.dart';
import 'recognition_service.dart';
import 'opera_repository.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  String? _errore;
  bool _elaborazione = false;
  RisultatoRiconoscimento? _risultato;

  final _recognitionService = RecognitionService();

  @override
  void initState() {
    super.initState();
    _inizializzaCamera();
    _recognitionService.inizializza();
  }

  Future<void> _inizializzaCamera() async {
    final permesso = await Permission.camera.request();
    if (!permesso.isGranted) {
      setState(() => _errore = 'Permesso camera negato');
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() => _errore = 'Nessuna camera trovata');
      return;
    }

    _controller = CameraController(cameras.first, ResolutionPreset.medium);
    await _controller!.initialize();

    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _riconosci() async {
    if (!_isInitialized || _elaborazione) return;

    setState(() => _elaborazione = true);

    final foto = await _controller!.takePicture();
    final bytes = await foto.readAsBytes();
    final risultato = await _recognitionService.riconosci(bytes);

    if (mounted) {
      setState(() {
        _risultato = risultato;
        _elaborazione = false;
      });

      if (risultato != null && risultato.isAffidabile) {
        context.read<AppState>().riconosciOpera(risultato.nomeOpera);
        final operaTrovata = OperaRepository.trovaPerNomeML(
          risultato.nomeOpera,
        );
        context.read<AppState>().selezionaOpera(operaTrovata);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recognitionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riconosci Opera')),
      body: _buildBody(),
      floatingActionButton: _isInitialized
          ? FloatingActionButton.extended(
              onPressed: _elaborazione ? null : _riconosci,
              icon: _elaborazione
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_elaborazione ? 'Analisi...' : 'Riconosci'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_errore != null) return Center(child: Text(_errore!));

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        CameraPreview(_controller!),

        if (_risultato != null)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.black87,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Opera rilevata:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _risultato!.nomeOpera,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),

                    Text(
                      'Confidenza: ${(_risultato!.confidenza * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white70),
                    ),

                    if (!_risultato!.isAffidabile)
                      const Text(
                        'Confidenza bassa — avvicina la camera',
                        style: TextStyle(color: Colors.orange),
                      ),

                    if (_risultato!.isAffidabile) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              context.push('/ar/${_risultato!.nomeOpera}'),
                          icon: const Icon(Icons.view_in_ar),
                          label: const Text('Avvia AR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
