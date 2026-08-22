import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_config.dart';
import '../core/app_state.dart';
import '../data/models.dart';
import '../widgets/chat_widget.dart';
import '../widgets/menu_widget.dart';
import '../services/package_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/update_service.dart';

class HomeScreen extends StatefulWidget {
  final String? titoloFonteIniziale;
  final List<String>? idsFonteIniziale;

  const HomeScreen({
    super.key,
    this.titoloFonteIniziale,
    this.idsFonteIniziale,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _syncInCorso = false;
  String? _titoloFonteSelezionata;
  List<String>? _idsFonteSelezionata;
  BookModel? _operaRiconosciutaAR;
  AppState? _appState;

  @override
  void initState() {
    super.initState();

    _titoloFonteSelezionata = widget.titoloFonteIniziale;
    _idsFonteSelezionata = widget.idsFonteIniziale;
    _appState = context.read<AppState>();
    _appState?.addListener(_onAppStateChanged);

    _onAppStateChanged();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sincronizzaPacchettoInBackground();
    });
  }

  @override
  void dispose() {
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        centerTitle: true,
        actions: [
          Builder(
            builder: (BuildContext context) {
              return IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu Principale',
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              );
            },
          ),
        ],
        title: Image.asset(
          'assets/magic-logo.png',
          height: 30,
          fit: BoxFit.contain,
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
      endDrawer: const MenuWidget(),
      body: ChatWidget(
        titoloFonteSelezionata: _titoloFonteSelezionata,
        bookIds: _idsFonteSelezionata,
        onFonteSelezionata: (titolo, ids) {
          setState(() {
            _titoloFonteSelezionata = titolo;
            _idsFonteSelezionata = ids;
            _operaRiconosciutaAR = null;
          });
        },
      ),
    );
  }

  // --- LOGICA ---
  void _onAppStateChanged() {
    if (!mounted) return;

    final operaSelezionata = _appState?.operaSelezionata;

    if (operaSelezionata != null && operaSelezionata != _operaRiconosciutaAR) {
      final isDifferent =
          _idsFonteSelezionata == null ||
          !_idsFonteSelezionata!.contains(operaSelezionata.id);

      if (isDifferent) {
        setState(() {
          _operaRiconosciutaAR = operaSelezionata;
          _titoloFonteSelezionata = operaSelezionata.titolo;
          _idsFonteSelezionata = [operaSelezionata.id];
        });
      }
    }
  }

  Future<void> _sincronizzaPacchettoInBackground() async {
    final storage = context.read<StorageService>();
    final authService = context.read<AuthService>();

    try {
      final updateService = UpdateService();
      final necessaria = await updateService.isSincronizzazioneNecessaria(
        AppConfig.packageId,
      );

      if (!necessaria) return;
      if (!mounted) return;

      setState(() => _syncInCorso = true);

      final packageService = PackageService(
        storage: storage,
        authService: authService,
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
}
