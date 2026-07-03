import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'main.dart';

class ARScreen extends StatefulWidget {
  final String nomeOpera;
  const ARScreen({super.key, required this.nomeOpera});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  bool _cameraReady = false;
  bool _overlayVisibile = false;

  // Animazione fade pannello
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Animazione slide pannello
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Animazione mirino pulsante
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();

    // Fade
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Slide dal basso
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    // Mirino pulsante
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scanAnimation = CurvedAnimation(
      parent: _scanController,
      curve: Curves.easeInOut,
    );
    _scanController.repeat(reverse: true);

    _inizializzaCamera();
  }

  Future<void> _inizializzaCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _controller = CameraController(cameras.first, ResolutionPreset.medium);
    await _controller!.initialize();
    if (mounted) setState(() => _cameraReady = true);
  }

  void _mostraOverlay() {
    setState(() => _overlayVisibile = true);
    _scanController.stop();
    _fadeController.forward();
    _slideController.forward();
  }

  void _nascondiOverlay() {
    _fadeController.reverse();
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() => _overlayVisibile = false);
        _scanController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opera = context.watch<AppState>().operaSelezionata;

    return Scaffold(
      appBar: AppBar(
        title: Text(opera?.titolo ?? widget.nomeOpera),
        actions: [
          if (_overlayVisibile)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _nascondiOverlay,
            ),
        ],
      ),
      body: _buildBody(opera),
    );
  }

  Widget _buildBody(Opera? opera) {
    if (!_cameraReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        CameraPreview(_controller!),

        // Mirino pulsante
        if (!_overlayVisibile)
          Center(
            child: AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Container(
                  width: 200,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white
                          .withOpacity(0.4 + _scanAnimation.value * 0.6),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: 0.4 + _scanAnimation.value * 0.6,
                      child: const Text(
                        'Punta sulla copertina',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Overlay con fade + slide
        if (_overlayVisibile)
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildPannelloAR(opera),
              ),
            ),
          ),

        // Bottone
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: ElevatedButton.icon(
              onPressed: _overlayVisibile ? _nascondiOverlay : _mostraOverlay,
              icon: Icon(
                  _overlayVisibile ? Icons.close : Icons.view_in_ar),
              label: Text(
                  _overlayVisibile ? 'Nascondi info' : 'Mostra info AR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPannelloAR(Opera? opera) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  opera?.titolo ?? widget.nomeOpera,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          if (opera != null) ...[
            _infoRiga('Autore', opera.autore),
            _infoRiga('Biblioteca', opera.biblioteca),
            _infoRiga('Periodo', opera.periodo),
            _infoRiga('Supporto', opera.supporto),
          ] else ...[
            _infoRiga('Biblioteca', 'Girolamini, Napoli'),
            _infoRiga('Periodo', 'Sec. XIV-XVII'),
            _infoRiga('Supporto', 'Pergamena'),
          ],
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green, width: 1),
            ),
            child: const Text(
              '✓ Opera riconosciuta',
              style:
                  TextStyle(color: Colors.greenAccent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRiga(String label, String valore) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              valore,
              style:
                  const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}