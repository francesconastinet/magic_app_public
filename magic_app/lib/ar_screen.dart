import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'media_service.dart';
import 'models.dart';
import 'widgets/audio_dialog.dart';
import 'widgets/image_dialog.dart';
import 'widgets/pdf_dialog.dart';
import 'widgets/text_dialog.dart';
import 'widgets/video_dialog.dart';

class ARScreen extends StatefulWidget {
  final String nomeOpera;
  const ARScreen({super.key, required this.nomeOpera});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  bool _cameraReady = false;
  bool _overlayVisibile = false;

  // Animazione fade overlay
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Animazione slide per il vecchio overlay
  // late AnimationController _slideController;
  // late Animation<Offset> _slideAnimation;

  // Animazione mirino pulsante
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();

    // Fade overlay
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Slide dal basso del vecchio overlay
    // _slideController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(milliseconds: 400),
    // );
    // _slideAnimation = Tween<Offset>(
    //   begin: const Offset(0, 0.3),
    //   end: Offset.zero,
    // ).animate(CurvedAnimation(
    //   parent: _slideController,
    //   curve: Curves.easeOut,
    // ));

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

    if (mounted) {
      setState(() => _cameraReady = true);

      // TODO: sostituire con la chiamata a RecognitionService
      if (!_overlayVisibile) _mostraOverlay();
    }
  }

  void _mostraOverlay() {
    setState(() => _overlayVisibile = true);
    _scanController.stop();
    _fadeController.forward();
    // Vecchio overlay
    // _slideController.forward();
  }

  void _nascondiOverlay() {
    // Vecchio overlay
    // _fadeController.reverse();
    // _slideController.reverse().then((_) {
    //   if (mounted) {
    //     setState(() => _overlayVisibile = false);
    //     _scanController.repeat(reverse: true);
    //   }
    // });
    _fadeController.reverse().then((_) {
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
    // Vecchio overlay
    // _slideController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opera = context.watch<AppState>().operaSelezionata;

    return Scaffold(
      appBar: AppBar(
        title: Text(opera?.titolo ?? widget.nomeOpera),
      ),
      body: _buildBody(opera),
    );
  }

  Widget _buildBody(BookModel? opera) {
    if (!_cameraReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Usiamo un Center per evitare che la fotocamera si deformi
        Center(
          child: CameraPreview(_controller!),
        ),

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
                          .withValues(alpha: 0.4 + _scanAnimation.value * 0.6),
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

        // Vecchio overlay AR
        // if (_overlayVisibile)
        //   Center(
        //     child: FadeTransition(
        //       opacity: _fadeAnimation,
        //       child: SlideTransition(
        //         position: _slideAnimation,
        //         child: _buildPannelloAR(opera),
        //       ),
        //     ),
        //   ),

        if (_overlayVisibile && opera != null) ...[
          // Badge informativo dell'opera (Titolo, Autore, Anno)
          Positioned(
            top: 24,
            left: 40,
            right: 40,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Titolo con icona
                    Row(
                      children: [
                        const Icon(Icons.menu_book, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            opera.titolo,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6.0),
                      child: Divider(color: Colors.white24, height: 1),
                    ),
                    // Autore e Anno
                    Text(
                      'Autore: ${opera.autore}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Anno: ${opera.anno}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bubble per contenuti multimediali
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Builder(
                  builder: (context) {
                    final fileMultimediali = opera?.multimedia ?? [];

                    // Se l'opera non ha nessun media non disegniamo niente
                    if (fileMultimediali.isEmpty) return const SizedBox.shrink();

                    // Generiamo le bubble filtrando la lista di file
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBubble(
                            Icons.videocam,
                            'Video',
                            fileMultimediali.where(
                                    (m) => m.tipo == 'video').toList()
                        ),
                        _buildBubble(
                            Icons.audiotrack,
                            'Audio',
                            fileMultimediali.where(
                                    (m) => m.tipo == 'audio').toList()
                        ),
                        _buildBubble(
                            Icons.image,
                            'Immagini',
                            fileMultimediali.where(
                                    (m) => m.tipo == 'immagine').toList()
                        ),
                        _buildBubble(
                            Icons.picture_as_pdf,
                            'PDF',
                            fileMultimediali.where(
                                    (m) => m.tipo == 'pdf').toList()
                        ),
                        _buildBubble(
                            Icons.article,
                            'Testo',
                            fileMultimediali.where(
                                    (m) => m.tipo == 'testo').toList()
                        ),
                        _buildBubble(
                            Icons.link,
                            'Link',
                            fileMultimediali.where(
                                    (m) => m.tipo == 'link_esterno').toList()
                        ),
                      ],
                    );
                  }
                ),
              ),
            ),
          ),

          // Bottoni 'Chiudi overlay' e 'Chiedi alla chat'
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: IgnorePointer(
                  ignoring: !_overlayVisibile,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tasto per chiudere l'overlay
                      ElevatedButton.icon(
                        onPressed: _nascondiOverlay,
                        icon: const Icon(Icons.close),
                        label: const Text('Chiudi overlay'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Bottone per aprire la chat
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: aprire la chat
                          debugPrint("Apri chat per questa opera");
                        },
                        icon: const Icon(Icons.chat_bubble),
                        label: const Text('Chiedi alla Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

        // Pulsanti di Debug visibili durante lo sviluppo per simulare opere
        if (kDebugMode)
          Positioned(
            top: 150,
            left: 5,
            right: 260,
            child: Card(
              color: Colors.black87,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'MENU DEBUG',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8),
                      ),
                      onPressed: () {
                        final operaSimulata = BookModel(
                          id: 'xyz',
                          titolo: 'Divina Commedia',
                          autore: 'Dante Alighieri',
                          anno: '1321',
                          multimedia: [
                            MediaItem(
                                tipo: 'video',
                                titolo: 'Spiegazione in 2 minuti',
                                url: 'assets/media/video_01.mp4',
                                descrizione: 'Descrizione video'),
                            MediaItem(
                                tipo: 'audio',
                                titolo: 'Lettura Canto I',
                                url: 'assets/media/audio_01.mp3',
                                descrizione: 'Descrizione audio'),
                            MediaItem(
                                tipo: 'testo',
                                titolo: 'Riassunto trama',
                                url: 'assets/media/testo_01.txt',
                                descrizione: 'Descrizione testo'),
                            MediaItem(
                                tipo: 'immagine',
                                titolo: 'Copertina del libro',
                                url: 'assets/media/immagine_01.png',
                                descrizione: 'Descrizione immagine'),
                            MediaItem(
                                tipo: 'pdf',
                                titolo: 'Pdf Canto I',
                                url: 'assets/media/pdf_01.pdf',
                                descrizione: 'Descrizione pdf'),
                            MediaItem(
                                tipo: 'link_esterno',
                                titolo: 'Parafrasi Divina Commedia',
                                url: 'https://divinacommedia.weebly.com/',
                                descrizione: 'Descrizione link'),
                          ],
                        );
                        context.read<AppState>().selezionaOpera(operaSimulata);
                        _mostraOverlay();
                      },
                      child: const Text(
                          'Divina Commedia',
                          style: TextStyle(fontSize: 12)),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lime.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8),
                      ),
                      onPressed: () {
                        final operaSimulata = BookModel(
                          id: 'abc',
                          titolo: 'Promessi Sposi',
                          autore: 'Alessandro Manzoni',
                          anno: '1827',
                          multimedia: [
                            MediaItem(
                                tipo: 'audio',
                                titolo: 'Lettura Canto I',
                                url: 'assets/media/audio_01.mp3',
                                descrizione: 'Descrizione audio'),
                            for (var i = 1; i <= 10; i++)
                              MediaItem(
                                  tipo: 'testo',
                                  titolo: 'Riassunto Inferno',
                                  url: 'assets/media/testo_01.txt',
                                  descrizione: 'Descrizione testo'),
                            MediaItem(
                                tipo: 'pdf',
                                titolo: 'Pdf Canto I',
                                url: 'assets/media/pdf_01.pdf',
                                descrizione: 'Descrizione pdf'),
                          ],
                        );
                        context.read<AppState>().selezionaOpera(operaSimulata);
                        _mostraOverlay();
                      },
                      child: const Text(
                          'Promessi Sposi',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Vecchio overlay AR
  // Widget _buildPannelloAR(Opera? opera) {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 32),
  //     padding: const EdgeInsets.all(20),
  //     decoration: BoxDecoration(
  //       color: Colors.black.withValues(alpha: 0.75),
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: Colors.white24, width: 1),
  //     ),
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             const Icon(Icons.menu_book, color: Colors.white, size: 28),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               child: Text(
  //                 opera?.titolo ?? widget.nomeOpera,
  //                 style: const TextStyle(
  //                   color: Colors.white,
  //                   fontSize: 20,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const Divider(color: Colors.white24, height: 24),
  //         if (opera != null) ...[
  //           _infoRiga('Autore', opera.autore),
  //           _infoRiga('Biblioteca', opera.biblioteca),
  //           _infoRiga('Periodo', opera.periodo),
  //           _infoRiga('Supporto', opera.supporto),
  //         ] else ...[
  //           _infoRiga('Biblioteca', 'Girolamini, Napoli'),
  //           _infoRiga('Periodo', 'Sec. XIV-XVII'),
  //           _infoRiga('Supporto', 'Pergamena'),
  //         ],
  //         const SizedBox(height: 12),
  //         Container(
  //           padding:
  //               const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  //           decoration: BoxDecoration(
  //             color: Colors.green.withOpacity(0.3),
  //             borderRadius: BorderRadius.circular(20),
  //             border: Border.all(color: Colors.green, width: 1),
  //           ),
  //           child: const Text(
  //             '✓ Opera riconosciuta',
  //             style:
  //                 TextStyle(color: Colors.greenAccent, fontSize: 12),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Metodo per il vecchio overlay
  // Widget _infoRiga(String label, String valore) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 4),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         SizedBox(
  //           width: 80,
  //           child: Text(
  //             label,
  //             style:
  //                 const TextStyle(color: Colors.white54, fontSize: 13),
  //           ),
  //         ),
  //         Expanded(
  //           child: Text(
  //             valore,
  //             style:
  //                 const TextStyle(color: Colors.white, fontSize: 13),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildBubble(IconData icona, String tipo, List<MediaItem> mediaList) {
    // Se la lista è vuota non disegniamo nulla
    if (mediaList.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: FloatingActionButton(
        heroTag: 'bubble_$tipo', // Questo evita conflitti tra i FAB
        backgroundColor: Colors.black.withValues(alpha: 0.75),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
        onPressed: () => _mostraListaMedia(tipo, mediaList),
        child: Icon(icona),
      ),
    );
  }

  void _mostraListaMedia(String titoloTipo, List<MediaItem> mediaList) {
    // La BottomSheet occupa la parte inferiore dello schermo
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      barrierColor: Colors.transparent, // Non scurisce la fotocamera dietro
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header del BottomSheet
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      'Contenuti: $titoloTipo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${mediaList.length} elementi',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),

              // Lista scrollabile degli elementi
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true, // Adatta l'altezza al numero di elementi
                  itemCount: mediaList.length,
                  itemBuilder: (context, index) {
                    final item = mediaList[index];
                    return ListTile(
                      leading: const Icon(Icons.arrow_right, color: Colors.white70),
                      title: Text(
                        item.titolo,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context); // Chiude la lista scorrevole

                        // Gestione Link Esterni
                        if (item.tipo == 'link_esterno') {
                          context.read<MediaService>().apriUrl(item.url);
                          return;
                        }

                        // Gestione Media Interni
                        showDialog(
                          context: context,
                          builder: (context) {
                            switch (item.tipo) {
                              case 'testo':
                                return TextDialog(
                                  titolo: item.titolo,
                                  textPath: item.url,
                                );
                              case 'immagine':
                                return ImageDialog(
                                  titolo: item.titolo,
                                  imagePath: item.url,
                                );
                              case 'video':
                                return VideoDialog(
                                  titolo: item.titolo,
                                  videoPath: item.url,
                                );
                              case 'audio':
                                return AudioDialog(
                                  titolo: item.titolo,
                                  audioPath: item.url,
                                );
                              case 'pdf':
                                return PdfDialog(
                                  titolo: item.titolo,
                                  pdfPath: item.url,
                                );
                              default:
                                return const AlertDialog(
                                  title: Text('Formato non supportato'),
                                );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}