import 'package:magic_app/models.dart';
import 'app_config.dart';
import 'media_service.dart';
import 'package_service.dart';
import 'collection_screen.dart';
import 'manuscript_screen.dart';
import 'opera_repository.dart';
import 'package_storage.dart';
import 'auth_service.dart';
import 'update_service.dart';
import 'recognition_service.dart';
import 'ar_screen.dart';
// import 'api_service.dart'; // usato solo dal bottone folder_zip
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

// --- MODELLO DATI OPERA ---
// Vecchio modello sostituito con BookModel
// class Opera {
//   final String id;
//   final String titolo;
//   final String autore;
//   final String biblioteca;
//   final String periodo;
//   final String supporto;
//
//   const Opera({
//     required this.id,
//     required this.titolo,
//     required this.autore,
//     required this.biblioteca,
//     required this.periodo,
//     required this.supporto,
//   });
// }

// --- APP STATE ---
class AppState extends ChangeNotifier {
  int _opereRiconosciute = 0;
  String? _ultimaOpera;
  BookModel? _operaSelezionata;

  int get opereRiconosciute => _opereRiconosciute;
  String? get ultimaOpera => _ultimaOpera;
  BookModel? get operaSelezionata => _operaSelezionata;

  void riconosciOpera(String nomeOpera) {
    _ultimaOpera = nomeOpera;
    _opereRiconosciute++;
    notifyListeners();
  }

  void selezionaOpera(BookModel opera) {
    _operaSelezionata = opera;
    notifyListeners();
  }
}

// --- ROUTER ---
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/camera', builder: (context, state) => const CameraScreen()),
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
    MultiProvider(
      providers: [
        // Stato Globale dell'app
        // (Usa ChangeNotifierProvider perché la UI deve reagire ai cambiamenti)
        ChangeNotifierProvider(create: (context) => AppState()),

        // NUOVO — AuthService come ChangeNotifierProvider:
        // notifica i widget in ascolto quando cambia lo stato di
        // login/logout, ed essendo un provider e' UNA SOLA istanza condivisa
        // in tutta l'app (niente piu' login ripetuti ad ogni download).
        ChangeNotifierProvider(create: (context) => AuthService()),

        // Servizi di Logica
        // (Usano il Provider base perché non hanno uno stato che cambia)
        Provider(create: (context) => PackageStorage()),
        Provider(create: (context) => MediaService()),
      ],
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
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
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
// da StatelessWidget a StatefulWidget per poter lanciare la
// sync automatica in background dentro initState() all'avvio dell'app.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // true mentre la sync automatica sta scaricando in background
  bool _syncInCorso = false;

  // NUOVO — Future delle collezioni, calcolata UNA SOLA VOLTA in initState.
  // Se la mettessimo dentro build(), ogni volta che _syncInCorso cambia
  // (quindi build() viene richiamato) verrebbe creata una Future nuova,
  // e il FutureBuilder sotto tornerebbe a mostrare "Caricamento..." anche
  // se le collezioni erano gia' state lette.
  late Future<List<CollectionV2Model>> _collezioniFuture;

  @override
  void initState() {
    super.initState();
    _collezioniFuture = _caricaCollezioni(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sincronizzaPacchettoInBackground();
    });
  }

  // NUOVO — legge le collezioni dal pacchetto per
  // mostrarle in cima alla lista principale: 

  Future<List<CollectionV2Model>> _caricaCollezioni(BuildContext context) {
    final service = PackageService(
      storage: context.read<PackageStorage>(),
      authService: context.read<AuthService>(),
    );
    return service.leggiCollezioniV2(AppConfig.packageId);
  }

  // SYNC AUTOMATICA SILENZIOSA (check reale via endpoint)
  // Sostituisce il vecchio bottone nuvola manuale. UpdateService decide
  // OGNI QUANTO controllare (throttling, 24h); PackageService.sincronizzaSeCambiato
  // decide SE scaricare davvero, chiamando l'endpoint /check/ .
  Future<void> _sincronizzaPacchettoInBackground() async {
    try {
      final updateService = UpdateService();
      final necessaria = await updateService.isSincronizzazioneNecessaria(
        AppConfig.packageId,
      );

      if (!necessaria) {
        debugPrint('[SYNC] Ultimo controllo recente (<24h) — skip');
        return;
      }

      if (mounted) setState(() => _syncInCorso = true);
      debugPrint('[SYNC] Avvio controllo/sync automatica in background...');

      // NUOVO — dipendenze prese dal Provider invece di crearle al volo
      final packageService = PackageService(
        storage: context.read<PackageStorage>(),
        authService: context.read<AuthService>(),
      );

      final risultato = await packageService.sincronizzaSeCambiato(
        packageId: AppConfig.packageId,
        versione:
            'api-latest', // placeholder: non ha ancora un endpoint di versione numerica
        onStato: (msg) {
          debugPrint('[SYNC] $msg');
        },
      );

      if (risultato.successo) {
        if (risultato.scaricato) {
          debugPrint('[SYNC] Sync completata — pacchetto aggiornato');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pacchetto aggiornato in background'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          debugPrint(
            '[SYNC] Pacchetto gia\' aggiornato — nessun download necessario',
          );
        }
      } else {
        debugPrint(
          '[SYNC] Sync automatica fallita — verra\' ritentata al prossimo avvio',
        );
      }
    } catch (e) {
      debugPrint('[SYNC] Errore sync automatica: $e');
    } finally {
      if (mounted) setState(() => _syncInCorso = false);
    }
  }

  // NUOVO — sezione collezioni in cima alla lista, con divisore prima dei
  // singoli volumi. Se non ci sono collezioni (pacchetto non ancora
  // scaricato, o errore), non mostra nulla, la lista libri sotto resta
  // comunque visibile e funzionante.
  Widget _buildSezioneCollezioni(BuildContext context, ColorScheme colorScheme) {
    return FutureBuilder<List<CollectionV2Model>>(
      future: _collezioniFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final collezioni = snapshot.data ?? [];
        if (collezioni.isEmpty) {
          // Nessuna collezione (pacchetto non ancora scaricato o vuoto) —
          // niente da mostrare qui, la lista libri prosegue normalmente
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Collezioni',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...collezioni.map(
              (collection) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.collections_bookmark,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    collection.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: collection.description.isNotEmpty
                      ? Text(collection.description)
                      : null,
                  trailing: Chip(
                    label: Text('${collection.bookIds.length} libri'),
                    backgroundColor: colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManuscriptScreen(
                          packageId: AppConfig.packageId,
                          collectionId: collection.id,
                          collectionName: collection.name,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const Divider(thickness: 1, height: 24),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final opere = OperaRepository.tutteLeOpere();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        // il titolo non e' piu' nello slot 'title' (che si
        // centra solo nello spazio libero tra leading e actions, quindi
        // appariva spostato a sinistra a causa delle icone a destra), ma
        // dentro 'flexibleSpace', che copre l'intera larghezza dell'AppBar
        // e quindi si centra davvero rispetto allo schermo.
        title: null,
        flexibleSpace: Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'MAGIC',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimary,
                ),
              ),
              Text(
                'Biblioteca dei Girolamini',
                style: TextStyle(fontSize: 12, color: colorScheme.onPrimary),
              ),
            ],
          ),
        ),
        // barra sottile mentre la sync automatica e' in corso
        bottom: _syncInCorso
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: colorScheme.onPrimary,
                  backgroundColor: colorScheme.primary,
                ),
              )
            : null,
        actions: [
          // --- Vecchia struttura ---
          // BOTTONE DOWNLOAD DA API INTERNA (solo VPN) — "bottone nuvola"
          // manuale, sostituito dalla sync automatica silenziosa
          // (vedi _sincronizzaPacchettoInBackground in initState).
          // Lasciato commentato per riferimento / rollback rapido.
          // IconButton(
          //   icon: const Icon(Icons.cloud_download),
          //   tooltip: 'Scarica da API (VPN)',
          //   onPressed: () async {
          //     try {
          //       final service = PackageService();
          //       String statoMessaggio = 'Connessione...';
          //
          //       showDialog(
          //         context: context,
          //         barrierDismissible: false,
          //         builder: (ctx) => StatefulBuilder(
          //           builder: (ctx, setStateDlg) => AlertDialog(
          //             title: const Text('Download da API...'),
          //             content: Column(
          //               mainAxisSize: MainAxisSize.min,
          //               children: [
          //                 const CircularProgressIndicator(),
          //                 const SizedBox(height: 16),
          //                 Text(statoMessaggio),
          //               ],
          //             ),
          //           ),
          //         ),
          //       );
          //
          //       final successo = await service.scaricaEEstraiDaApi(
          //         packageId: AppConfig.packageId,
          //         versione: 'api-latest',
          //         onStato: (msg) {
          //           statoMessaggio = msg;
          //         },
          //       );
          //
          //       if (context.mounted && Navigator.canPop(context)) {
          //         Navigator.pop(context);
          //       }
          //
          //       await Future.delayed(const Duration(milliseconds: 200));
          //
          //       if (context.mounted) {
          //         ScaffoldMessenger.of(context).showSnackBar(
          //           SnackBar(
          //             content: Text(successo
          //                 ? 'Pacchetto API installato!'
          //                 : 'Errore download API — verifica VPN'),
          //             backgroundColor:
          //                 successo ? Colors.green : Colors.red,
          //           ),
          //         );
          //       }
          //     } catch (e) {
          //       if (context.mounted && Navigator.canPop(context)) {
          //         Navigator.pop(context);
          //       }
          //       if (context.mounted) {
          //         ScaffoldMessenger.of(context).showSnackBar(
          //           SnackBar(content: Text('Errore: $e')),
          //         );
          //       }
          //     }
          //   },
          // ),
          // BOTTONE AGGIORNAMENTO PACCHETTO — flusso ZIP mock/manifest
          // (GitHub Releases + Gist), ormai sostituito dalla sync
          // automatica reale con l'endpoint /check/.

          // IconButton(
          //   icon: const Icon(Icons.folder_zip),
          //   tooltip: 'Aggiorna pacchetto',
          //   onPressed: () async {
          //     try {
          //       final service = PackageService(
          //         storage: context.read<PackageStorage>(),
          //         authService: context.read<AuthService>(),
          //       );
          //
          //       final manifest = await ApiService().scaricaManifest();
          //       final versioneDisponibile = manifest.version;
          //
          //       final aggiornamentoDisponibile = await service
          //           .isAggiornamentoDisponibile(
          //             AppConfig.packageId,
          //             versioneDisponibile,
          //           );
          //
          //       if (!aggiornamentoDisponibile && context.mounted) {
          //         ScaffoldMessenger.of(context).showSnackBar(
          //           SnackBar(
          //             content: Text(
          //               'Pacchetto aggiornato — versione $versioneDisponibile',
          //             ),
          //             backgroundColor: Colors.green,
          //           ),
          //         );
          //         return;
          //       }
          //
          //       if (!context.mounted) return;
          //       double progresso = 0;
          //
          //       showDialog(
          //         context: context,
          //         barrierDismissible: false,
          //         builder: (ctx) => StatefulBuilder(
          //           builder: (ctx, setStateDlg) => AlertDialog(
          //             title: Text('Download versione $versioneDisponibile...'),
          //             content: Column(
          //               mainAxisSize: MainAxisSize.min,
          //               children: [
          //                 LinearProgressIndicator(value: progresso),
          //                 const SizedBox(height: 8),
          //                 Text('${(progresso * 100).toStringAsFixed(0)}%'),
          //               ],
          //             ),
          //           ),
          //         ),
          //       );
          //
          //       await service.scaricaEEstrai(
          //         url: AppConfig.packageUrl,
          //         packageId: AppConfig.packageId,
          //         versione: versioneDisponibile,
          //         onProgress: (received, total) {
          //           progresso = received / total;
          //         },
          //       );
          //
          //       if (context.mounted && Navigator.canPop(context)) {
          //         Navigator.pop(context);
          //       }
          //
          //       await Future.delayed(const Duration(milliseconds: 200));
          //
          //       if (context.mounted) {
          //         showDialog(
          //           context: context,
          //           builder: (_) => AlertDialog(
          //             title: Text('Versione $versioneDisponibile installata!'),
          //             content: const Text(
          //               'Il pacchetto e\' stato scaricato e installato correttamente.',
          //             ),
          //             actions: [
          //               TextButton(
          //                 onPressed: () => Navigator.pop(context),
          //                 child: const Text('OK'),
          //               ),
          //             ],
          //           ),
          //         );
          //       }
          //     } catch (e) {
          //       if (context.mounted && Navigator.canPop(context)) {
          //         Navigator.pop(context);
          //       }
          //       if (context.mounted) {
          //         ScaffoldMessenger.of(
          //           context,
          //         ).showSnackBar(SnackBar(content: Text('Errore: $e')));
          //       }
          //     }
          //   },
          // ),
          // BOTTONE COLLEZIONI — rimosso dall'AppBar
      
          // IconButton(
          //   icon: const Icon(Icons.collections_bookmark),
          //   tooltip: 'Collezioni',
          //   onPressed: () => context.push('/collezioni'),
          // ),
          // Badge "Viste: X" — contatore libri riconosciuti
          // dalla camera. La logica di
          // conteggio in AppState (opereRiconosciute) resta attiva e
          // funzionante, cosi' il dato non si perde se si vuole
          // ripristinare il badge in futuro.
          // Consumer<AppState>(
          //   builder: (context, appState, child) {
          //     return Padding(
          //       padding: const EdgeInsets.only(right: 16),
          //       child: Center(
          //         child: Container(
          //           padding: const EdgeInsets.symmetric(
          //             horizontal: 10,
          //             vertical: 4,
          //           ),
          //           decoration: BoxDecoration(
          //             color: colorScheme.onPrimary.withValues(alpha: 0.2),
          //             borderRadius: BorderRadius.circular(20),
          //           ),
          //           child: Text(
          //             'Viste: ${appState.opereRiconosciute}',
          //             style: TextStyle(
          //               color: colorScheme.onPrimary,
          //               fontSize: 14,
          //               fontWeight: FontWeight.bold,
          //             ),
          //           ),
          //         ),
          //       ),
          //     );
          //   },
          // ),
        ],
      ),
      // MODIFICATO — da ListView.builder (solo libri) a ListView con
      // children misti: sezione collezioni in cima, poi i singoli volumi sotto.
    
      body: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [
          _buildSezioneCollezioni(context, colorScheme),
          ...opere.map(
            (opera) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.menu_book,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  opera.titolo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(opera.autore),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: colorScheme.primary,
                ),
                onTap: () {
                  context.read<AppState>().selezionaOpera(opera);
                  context.push('/opera/${opera.id}');
                },
              ),
            ),
          ),
        ],
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
                  child: Icon(
                    Icons.menu_book,
                    size: 48,
                    color: colorScheme.onPrimaryContainer,
                  ),
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
                          // Vecchia struttura per modello Opera
                          // _infoRiga(context, 'Biblioteca', opera.biblioteca),
                          // const Divider(),
                          // _infoRiga(context, 'Periodo', opera.periodo),
                          // const Divider(),
                          // _infoRiga(context, 'Supporto', opera.supporto),
                          _infoRiga(
                            context,
                            'Biblioteca',
                            'Biblioteca dei Girolamini',
                          ),
                          const Divider(),
                          _infoRiga(context, 'Anno', opera.anno),
                          const Divider(),
                          _infoRiga(context, 'Supporto', 'Carta'),
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 250,
                          child: ModelViewer(
                            src:
                                'https://modelviewer.dev/shared-assets/models/Astronaut.glb',
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
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
                    onPressed: () => context.push('/ar/${opera?.titolo ?? id}'),
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
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: Text(valore, style: const TextStyle(fontSize: 14))),
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