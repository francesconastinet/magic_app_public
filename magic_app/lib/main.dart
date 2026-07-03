import 'app_config.dart';
import 'package_service.dart';
import 'collection_screen.dart';
import 'opera_repository.dart';
import 'recognition_service.dart';
import 'ar_screen.dart';
import 'api_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

// --- MODELLO DATI OPERA ---
class Opera {
  final String id;
  final String titolo;
  final String autore;
  final String biblioteca;
  final String periodo;
  final String supporto;

  const Opera({
    required this.id,
    required this.titolo,
    required this.autore,
    required this.biblioteca,
    required this.periodo,
    required this.supporto,
  });
}

// --- APP STATE ---
class AppState extends ChangeNotifier {
  int _opereRiconosciute = 0;
  String? _ultimaOpera;
  Opera? _operaSelezionata;

  int get opereRiconosciute => _opereRiconosciute;
  String? get ultimaOpera => _ultimaOpera;
  Opera? get operaSelezionata => _operaSelezionata;

  void riconosciOpera(String nomeOpera) {
    _ultimaOpera = nomeOpera;
    _opereRiconosciute++;
    notifyListeners();
  }

  void selezionaOpera(Opera opera) {
    _operaSelezionata = opera;
    notifyListeners();
  }
}

// --- ROUTER ---
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/camera',
      builder: (context, state) => const CameraScreen(),
    ),
    GoRoute(
      path: '/collezioni',
      builder: (context, state) => const CollectionScreen(),
    ),
    GoRoute(
      path: '/ar/:nome',
      builder: (context, state) {
        final nome = state.pathParameters['nome']!;
        return ARScreen(nomeOpera: nome);
      },
    ),
    GoRoute(
      path: '/opera/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DettaglioScreen(id: id);
      },
    ),
  ],
);

// --- APP ---
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const MagicApp(),
    ),
  );
}

class MagicApp extends StatelessWidget {
  const MagicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MAGIC OR8.2',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B4513),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Georgia',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
        cardTheme: const CardThemeData(
          elevation: 3,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}

// --- SCHERMATA HOME ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final opere = OperaRepository.tutteLeOpere();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: const Column(
          children: [
            Text('MAGIC',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Biblioteca dei Girolamini',
                style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          // BOTTONE DOWNLOAD ZIP - versionamento
          IconButton(
            icon: const Icon(Icons.folder_zip),
            tooltip: 'Aggiorna pacchetto',
            onPressed: () async {
              try {
                final service = PackageService();

                // 1. Scarica manifest per ottenere versione disponibile
                final manifest = await ApiService().scaricaManifest();
                final versioneDisponibile = manifest.version;

                // 2. Controlla se c'e' un aggiornamento disponibile
                final aggiornamentoDisponibile =
                    await service.isAggiornamentoDisponibile(
                        AppConfig.packageId, versioneDisponibile);

                if (!aggiornamentoDisponibile && context.mounted) {
                  // Pacchetto gia' aggiornato — nessun download necessario
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Pacchetto aggiornato — versione $versioneDisponibile'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  return;
                }

                if (!context.mounted) return;
                double progresso = 0;

                // 3. Mostra dialog con progress bar
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => StatefulBuilder(
                    builder: (ctx, setStateDlg) => AlertDialog(
                      title: Text(
                          'Download versione $versioneDisponibile...'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LinearProgressIndicator(value: progresso),
                          const SizedBox(height: 8),
                          Text(
                              '${(progresso * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                    ),
                  ),
                );

                // 4. Scarica ed estrai — passa la versione per salvarla
                await service.scaricaEEstrai(
                  // URL e packageId da AppConfig — non hardcodati
                  url: AppConfig.packageUrl,
                  packageId: AppConfig.packageId,
                  versione: versioneDisponibile,
                  onProgress: (received, total) {
                    progresso = received / total;
                  },
                );

                if (context.mounted) Navigator.pop(context);

                // 5. Legge ms001 dal disco dopo il download
                final info = await service.leggiInfoManoscritto(
                    AppConfig.packageId, 'percorso_medievale', 'ms001');

                // 6. Test caricamento modello ML dinamico
                bool modelloCaricato = false;
                try {
                  final riconoscitore = RecognitionService();
                  await riconoscitore.inizializzaDaFile(
                      AppConfig.packageId, 'percorso_medievale');
                  riconoscitore.dispose();
                  modelloCaricato = true;
                } catch (_) {
                  modelloCaricato = false;
                }

                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(
                          'Versione $versioneDisponibile installata!'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (info != null) ...[
                            const Text('ms001 dal disco:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('Titolo: ${info['titolo']}'),
                            Text('Autore: ${info['autore']}'),
                            Text('Periodo: ${info['periodo']}'),
                            const SizedBox(height: 8),
                          ],
                          // Risultato test modello ML
                          Text(
                            modelloCaricato
                                ? 'Modello ML: caricato dal pacchetto ✓'
                                : 'Modello ML: errore caricamento ✗',
                            style: TextStyle(
                              color: modelloCaricato
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Errore: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.collections_bookmark),
            tooltip: 'Collezioni',
            onPressed: () => context.push('/collezioni'),
          ),
          Consumer<AppState>(
            builder: (context, appState, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.onPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Viste: ${appState.opereRiconosciute}',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: opere.length,
        itemBuilder: (context, index) {
          final opera = opere[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.menu_book,
                    color: colorScheme.onPrimaryContainer),
              ),
              title: Text(opera.titolo,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(opera.autore),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: colorScheme.primary),
              onTap: () {
                context.read<AppState>().selezionaOpera(opera);
                context.push('/opera/${opera.id}');
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/camera'),
        icon: const Icon(Icons.camera_alt),
        label: const Text('Riconosci'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }
}

// --- SCHERMATA DETTAGLIO ---
class DettaglioScreen extends StatelessWidget {
  final String id;
  const DettaglioScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: Text('Opera $id'),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final opera = appState.operaSelezionata;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 48,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(Icons.menu_book,
                      size: 48, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 20),
                Text(
                  opera?.titolo ?? 'Opera $id',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  opera?.autore ?? '',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (opera != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _infoRiga(context, 'Biblioteca', opera.biblioteca),
                          const Divider(),
                          _infoRiga(context, 'Periodo', opera.periodo),
                          const Divider(),
                          _infoRiga(context, 'Supporto', opera.supporto),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modello 3D',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 250,
                          child: ModelViewer(
                            src: 'https://modelviewer.dev/shared-assets/models/Astronaut.glb',
                            alt: 'Modello 3D opera',
                            ar: false,
                            autoRotate: true,
                            cameraControls: true,
                            backgroundColor: const Color(0xFFF5F0E8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Placeholder — modello 3D definitivo da caricare',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (appState.ultimaOpera != null)
                  Chip(
                    avatar: const Icon(Icons.check_circle, size: 18),
                    label: Text('Ultima vista: ${appState.ultimaOpera}'),
                    backgroundColor: colorScheme.primaryContainer,
                  ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/ar/${opera?.titolo ?? id}'),
                    icon: const Icon(Icons.view_in_ar),
                    label: const Text('Avvia Realtà Aumentata'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRiga(BuildContext context, String label, String valore) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                )),
          ),
          Expanded(
            child: Text(valore, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// --- SCHERMATA CAMERA ---
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
        final operaTrovata =
            OperaRepository.trovaPerNomeML(risultato.nomeOpera);
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
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
                          onPressed: () => context
                              .push('/ar/${_risultato!.nomeOpera}'),
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