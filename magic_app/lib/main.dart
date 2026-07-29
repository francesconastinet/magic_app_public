import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'app_config.dart';
import 'chat_service.dart';
import 'chat_widget.dart';
import 'media_service.dart';
import 'models.dart';
import 'package_service.dart';
import 'collection_screen.dart';
import 'opera_repository.dart';
import 'package_storage.dart';
import 'auth_service.dart';
import 'update_service.dart';
import 'recognition_service.dart';
import 'ar_screen.dart';

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

        // NUOVO — ChatService globale
        ChangeNotifierProvider(create: (context) => ChatService()),

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
  bool _syncInCorso = false;
  late Future<List<CollectionV2Model>> _collezioniFuture;

  // --- STATO CHAT ---
  String? _titoloFonteSelezionata;
  List<String>? _idsFonteSelezionata;

  // --- STATO RICERCA FONTI ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // --- STATO MOCK LOGIN (Da rimuovere quando ci sarà il backend) ---
  String? _mockLoggedUser;

  @override
  void initState() {
    super.initState();
    _collezioniFuture = _caricaCollezioni(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sincronizzaPacchettoInBackground();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<CollectionV2Model>> _caricaCollezioni(
    BuildContext context,
  ) async {
    return [
      CollectionV2Model(
        id: 'coll_01',
        name: 'Percorso Medievale',
        description:
            'Una selezione di manoscritti risalenti al periodo medievale.',
        bookIds: ['001', '002'],
      ),
      CollectionV2Model(
        id: 'coll_02',
        name: 'Codici Miniati',
        description: 'Le opere più belle decorate con miniature e capilettera.',
        bookIds: ['003'],
      ),
    ];
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

  // --- DIALOG MOCK PER IL LOGIN ---
  void _mostraDialogLogin() {
    final colorScheme = Theme.of(context).colorScheme;
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            titlePadding: EdgeInsets.zero,
            clipBehavior: Clip.hardEdge,
            title: Container(
              color: colorScheme.primaryContainer,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.login, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Text(
                    'Accedi',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Inserisci un nome utente e una password.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: userCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nome Utente',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final user = userCtrl.text.trim();
                        if (user.isEmpty) return;

                        setStateDialog(() => isLoading = true);
                        if (!ctx.mounted) return;

                        Navigator.pop(ctx);
                        setState(() {
                          _mockLoggedUser = user;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Benvenuto, $_mockLoggedUser!',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Accedi'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- PULSANTE RESET FONTI ---
  Widget _buildResetButton(BuildContext context, ColorScheme colorScheme) {
    if (_titoloFonteSelezionata == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: TextButton.icon(
        onPressed: () {
          setState(() {
            _titoloFonteSelezionata = null;
            _idsFonteSelezionata = null;
          });
          Navigator.pop(context);
        },
        icon: const Icon(Icons.lock_open, size: 14),
        label: const Text('Sblocca le fonti', style: TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: colorScheme.primary,
          backgroundColor: colorScheme.surface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  // --- BARRA DI RICERCA ---
  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cerca una fonte...',
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  // --- SEZIONE COLLEZIONI ---
  Widget _buildSezioneCollezioni(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return FutureBuilder<List<CollectionV2Model>>(
      future: _collezioniFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        var collezioni = snapshot.data ?? [];

        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          collezioni = collezioni
              .where((c) => c.name.toLowerCase().contains(query))
              .toList();
        }

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
                  Navigator.pop(context);
                  setState(() {
                    _titoloFonteSelezionata = collection.name;
                    _idsFonteSelezionata = collection.bookIds;
                  });
                },
              ),
            ),
            const Divider(),
          ],
        );
      },
    );
  }

  // --- SEZIONE LIBRI ---
  Widget _buildSezioneLibri(BuildContext context, ColorScheme colorScheme) {
    var opere = OperaRepository.tutteLeOpere();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      opere = opere
          .where(
            (o) =>
                o.titolo.toLowerCase().contains(query) ||
                o.autore.toLowerCase().contains(query),
          )
          .toList();
    }

    if (opere.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Tutti i Manoscritti',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ),
        ...opere.map(
          (opera) => ListTile(
            leading: const Icon(Icons.menu_book),
            title: Text(opera.titolo, style: const TextStyle(fontSize: 14)),
            subtitle: Text(opera.autore, style: const TextStyle(fontSize: 12)),
            onTap: () {
              context.read<AppState>().selezionaOpera(opera);
              Navigator.pop(context);
              setState(() {
                _titoloFonteSelezionata = opera.titolo;
                _idsFonteSelezionata = [opera.id];
              });
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: colorScheme.primaryContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fonti Disponibili',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    _buildResetButton(context, colorScheme),
                  ],
                ),
              ),

              _buildSearchBar(colorScheme),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildSezioneCollezioni(context, colorScheme),
                    _buildSezioneLibri(context, colorScheme),

                    if (_searchQuery.isNotEmpty)
                      FutureBuilder<List<CollectionV2Model>>(
                        future: _collezioniFuture,
                        builder: (context, snapshot) {
                          final collezioni = snapshot.data ?? [];
                          final query = _searchQuery.toLowerCase();
                          final haCollezioni = collezioni.any(
                            (c) => c.name.toLowerCase().contains(query),
                          );
                          final haLibri = OperaRepository.tutteLeOpere().any(
                            (o) =>
                                o.titolo.toLowerCase().contains(query) ||
                                o.autore.toLowerCase().contains(query),
                          );

                          if (!haCollezioni && !haLibri) {
                            return Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Center(
                                child: Text(
                                  'Nessun risultato trovato.',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ==========================================
              // SEZIONE GESTIONE E SALVATAGGI
              // ==========================================
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'Chat',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              ListTile(
                dense: true,
                leading: Icon(
                  Icons.mobile_screen_share,
                  color: colorScheme.primary,
                ),
                title: const Text('Condividi Chat'),
                onTap: () async {
                  Navigator.pop(context);
                  final chatService = context.read<ChatService>();

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  final codice = await chatService.generaCodiceCondivisione();
                  if (!context.mounted) return;
                  Navigator.pop(context);

                  if (codice != null) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        titlePadding: EdgeInsets.zero,
                        clipBehavior: Clip.hardEdge,
                        title: Container(
                          color: colorScheme.primaryContainer,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.mobile_screen_share,
                                color: colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Codice di Ripristino',
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0, bottom: 16.0),
                              child: Text(
                                'Usa questo codice per continuare la '
                                'conversazione su un altro dispositivo:',
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.only(
                                left: 24,
                                right: 8,
                                top: 8,
                                bottom: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    codice,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 6,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    color: colorScheme.primary,
                                    tooltip: 'Copia negli appunti',
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: codice),
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Codice copiato negli appunti!',
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Chiudi'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),

              ListTile(
                dense: true,
                leading: Icon(
                  Icons.settings_backup_restore,
                  color: colorScheme.primary,
                ),
                title: const Text('Ripristina Chat'),
                onTap: () {
                  Navigator.pop(context);
                  final codeController = TextEditingController();

                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      titlePadding: EdgeInsets.zero,
                      clipBehavior: Clip.hardEdge,
                      title: Container(
                        color: colorScheme.primaryContainer,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.settings_backup_restore,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Ripristina Chat',
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      content: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Usa un codice per continuare una conversazione.',
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: codeController,
                              maxLength: 6,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: 'Codice di 6 caratteri',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Annulla'),
                        ),
                        FilledButton(
                          onPressed: () async {
                            final codice = codeController.text.trim();
                            if (codice.length != 6) return;

                            Navigator.pop(ctx);
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            final successo = await context
                                .read<ChatService>()
                                .ripristinaSessione(codice);

                            if (!context.mounted) return;
                            Navigator.pop(context);

                            if (successo) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Sessione ripristinata con successo!',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Codice invalido o scaduto'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: const Text('Ripristina'),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Divider(height: 1),

              // ==========================================
              // NUOVA SEZIONE UTENTE (Mock)
              // ==========================================
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'Profilo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              if (_mockLoggedUser != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Chip(
                          avatar: Icon(
                            Icons.person,
                            color: colorScheme.onPrimaryContainer,
                          ),
                          label: Text(
                            _mockLoggedUser!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          backgroundColor: colorScheme.primaryContainer,
                          side: BorderSide.none,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        color: colorScheme.error,
                        tooltip: 'Esci',
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() => _mockLoggedUser = null);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logout effettuato')),
                          );
                        },
                      ),
                    ],
                  ),
                )
              else
                ListTile(
                  dense: true,
                  leading: Icon(Icons.login, color: colorScheme.primary),
                  title: const Text('Accedi / Registrati'),
                  onTap: () {
                    Navigator.pop(context); // Chiude il drawer
                    _mostraDialogLogin(); // Apre il popup di mock
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),

      // APP BAR
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        centerTitle: true,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Apri menu collezioni',
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
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
      ),

      // CHAT WIDGET
      body: ChatWidget(
        titoloFonteSelezionata: _titoloFonteSelezionata,
        bookIds: _idsFonteSelezionata,
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
