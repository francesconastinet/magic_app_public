import 'package:magic_app/models.dart';
import 'app_config.dart';
import 'chat_service.dart';
import 'media_service.dart';
import 'package_service.dart';
import 'collection_screen.dart';
import 'opera_repository.dart';
import 'package_storage.dart';
import 'auth_service.dart';
import 'update_service.dart';
import 'recognition_service.dart';
import 'ar_screen.dart';
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
  // --- STATO PACCHETTI ---
  bool _syncInCorso = false;
  late Future<List<CollectionV2Model>> _collezioniFuture;

  // --- STATO CHAT INTEGRATA ---
  final ChatService _chatService = ChatService();
  final List<MessaggioChat> _messaggi = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _botStaScrivendo = false;
  final List<FonteChat> _fonteTotali = [];
  bool _contextSessionCreata = false;
  bool _contextSessionInCorso = false;

  // Traccia se la chat è limitata a un libro o a una collezione
  String? _contestoAttivoNome;

  @override
  void initState() {
    super.initState();
    _collezioniFuture = _caricaCollezioni(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sincronizzaPacchettoInBackground();
      _aggiungiMessaggioBenvenutoGenerico();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- METODI GESTIONE PACCHETTO ---
  Future<List<CollectionV2Model>> _caricaCollezioni(BuildContext context) {
    final service = PackageService(
      storage: context.read<PackageStorage>(),
      authService: context.read<AuthService>(),
    );
    return service.leggiCollezioniV2(AppConfig.packageId);
  }

  Future<void> _sincronizzaPacchettoInBackground() async {
    try {
      final updateService = UpdateService();
      final necessaria = await updateService.isSincronizzazioneNecessaria(
        AppConfig.packageId,
      );
      if (!necessaria) return;

      if (mounted) setState(() => _syncInCorso = true);
      final packageService = PackageService(
        storage: context.read<PackageStorage>(),
        authService: context.read<AuthService>(),
      );

      final risultato = await packageService.sincronizzaSeCambiato(
        packageId: AppConfig.packageId,
        versione: 'api-latest',
        onStato: (msg) => debugPrint('[SYNC] $msg'),
      );

      if (risultato.successo && risultato.scaricato && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pacchetto aggiornato in background'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[SYNC] Errore sync automatica: $e');
    } finally {
      if (mounted) setState(() => _syncInCorso = false);
    }
  }

  // --- LOGICA CHAT ---
  void _aggiungiMessaggioBenvenutoGenerico() {
    setState(() {
      _messaggi.add(
        MessaggioChat(
          testo:
              'Ciao! Sono il tuo assistente virtuale per la Biblioteca dei Girolamini. '
              'Puoi farmi domande sull\'archivio, oppure aprire il menu a sinistra (☰) per selezionare '
              'una collezione o un libro specifico e usarlo come fonte.',
          isUtente: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void _scrollaInFondo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _impostaContestoChat(
    String nomeContesto,
    List<String> bookIds,
  ) async {
    if (_contestoAttivoNome == nomeContesto) return; // Già attivo

    setState(() {
      _contestoAttivoNome = nomeContesto;
      _contextSessionInCorso = true;
      _messaggi.add(
        MessaggioChat(
          testo:
              'Hai selezionato "$nomeContesto". Sto aggiornando le mie fonti...',
          isUtente: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollaInFondo();

    final successo = await _chatService.creaContextSession(bookIds);
    setState(() {
      _contextSessionCreata = successo;
      _contextSessionInCorso = false;
      _messaggi.add(
        MessaggioChat(
          testo: successo
              ? 'Fonti bloccate con successo! Ora risponderò basandomi esclusivamente su "$nomeContesto".'
              : 'Si è verificato un problema, ma proverò comunque ad aiutarti.',
          isUtente: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollaInFondo();
  }

  Future<void> _invia() async {
    final testo = _controller.text.trim();
    if (testo.isEmpty || _botStaScrivendo) return;

    setState(() {
      _messaggi.add(
        MessaggioChat(testo: testo, isUtente: true, timestamp: DateTime.now()),
      );
      _botStaScrivendo = true;
      _controller.clear();
    });
    _scrollaInFondo();

    try {
      final risposta = await _chatService.inviaMessaggio(testo);
      setState(() {
        _messaggi.add(risposta);
        _botStaScrivendo = false;
        // Aggiorna fonti totali
        for (final fonte in risposta.fonti) {
          if (!_fonteTotali.any(
            (f) => f.workId == fonte.workId && fonte.workId.isNotEmpty,
          )) {
            _fonteTotali.add(fonte);
          }
        }
      });
    } catch (e) {
      setState(() {
        _messaggi.add(
          MessaggioChat(
            testo: 'Errore durante la comunicazione col server. Riprova.',
            isUtente: false,
            timestamp: DateTime.now(),
          ),
        );
        _botStaScrivendo = false;
      });
    }
    _scrollaInFondo();
  }

  // --- WIDGET UI ---
  Widget _buildSezioneCollezioni(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return FutureBuilder<List<CollectionV2Model>>(
      future: _collezioniFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const SizedBox.shrink();
        final collezioni = snapshot.data ?? [];
        if (collezioni.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Collezioni',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            ...collezioni.map(
              (collection) => ListTile(
                leading: const Icon(Icons.collections_bookmark),
                title: Text(
                  collection.name,
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: Text(
                  '${collection.bookIds.length} vol.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(context); // Chiudi il menu laterale
                  _impostaContestoChat(collection.name, collection.bookIds);
                },
              ),
            ),
            const Divider(),
          ],
        );
      },
    );
  }

  Widget _buildBubble(MessaggioChat msg, ColorScheme colorScheme) {
    final isUtente = msg.isUtente;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUtente
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUtente
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUtente ? 16 : 4),
                bottomRight: Radius.circular(isUtente ? 4 : 16),
              ),
            ),
            child: Text(
              msg.testo,
              style: TextStyle(
                color: isUtente ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opere = OperaRepository.tutteLeOpere();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // 1. MENU LATERALE SINISTRO: Collezioni e Libri
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: colorScheme.primaryContainer,
                child: Text(
                  'Fonti Disponibili',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildSezioneCollezioni(context, colorScheme),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'Tutti i Libri',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    ...opere.map(
                      (opera) => ListTile(
                        leading: const Icon(Icons.menu_book),
                        title: Text(
                          opera.titolo,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          opera.autore,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          context.read<AppState>().selezionaOpera(opera);
                          Navigator.pop(context); // Chiudi il menu
                          _impostaContestoChat(opera.titolo, [opera.id]);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // 2. APP BAR AGGIORNATA PER EVITARE OVERLAP
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        centerTitle: true, // Forza il titolo al centro
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.center, // Allinea il testo al centro
          children: const [
            Text(
              'MAGIC',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('Biblioteca dei Girolamini', style: TextStyle(fontSize: 11)),
          ],
        ),
        bottom: _syncInCorso
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: colorScheme.onPrimary,
                ),
              )
            : null,
        actions: [
          // Bottone Riconosci: solo icona
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton.filled(
              onPressed: () => context.push('/camera'),
              icon: const Icon(Icons.camera_alt),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.onPrimary,
                foregroundColor: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),

      // 3. BODY: INTERFACCIA CHAT
      body: Column(
        children: [
          // Indicatore contesto attivo
          if (_contestoAttivoNome != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colorScheme.secondaryContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 16,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fonte attiva: $_contestoAttivoNome',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  if (_contextSessionInCorso)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    )
                  else
                    Icon(
                      _contextSessionCreata
                          ? Icons.lock_outline
                          : Icons.lock_open,
                      size: 16,
                      color: _contextSessionCreata
                          ? Colors.green
                          : Colors.orange,
                    ),
                ],
              ),
            ),

          // Area Messaggi
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messaggi.length + (_botStaScrivendo ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messaggi.length && _botStaScrivendo) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Sto elaborando...',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }
                return _buildBubble(_messaggi[index], colorScheme);
              },
            ),
          ),

          // Area Input Testo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Fai una domanda...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _invia(),
                    enabled: !_botStaScrivendo,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'chat_send_home',
                  onPressed: _botStaScrivendo ? null : _invia,
                  backgroundColor: colorScheme.primary,
                  child: Icon(Icons.send, color: colorScheme.onPrimary),
                ),
              ],
            ),
          ),
        ],
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
