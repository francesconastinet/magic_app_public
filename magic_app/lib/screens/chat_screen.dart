import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../models.dart';
import '../widgets/chat_widget.dart';
import '../services/package_service.dart';
import '../services/package_storage.dart';
import '../services/auth_service.dart';
import '../services/update_service.dart';
import '../widgets/menu_laterale_widget.dart';

class ChatScreen extends StatefulWidget {
  final String? titoloFonteIniziale;
  final List<String>? idsFonteIniziale;

  const ChatScreen({
    super.key,
    this.titoloFonteIniziale,
    this.idsFonteIniziale,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _syncInCorso = false;
  String? _titoloFonteSelezionata;
  List<String>? _idsFonteSelezionata;
  BookModel? _operaRiconosciutaAR;

  @override
  void initState() {
    super.initState();

    _titoloFonteSelezionata = widget.titoloFonteIniziale;
    _idsFonteSelezionata = widget.idsFonteIniziale;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sincronizzaPacchettoInBackground();
    });
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
                tooltip: 'Apri Menu Principale',
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

      endDrawer: DrawerWidget(),

      body: ChatWidget(
        titoloFonteSelezionata: _titoloFonteSelezionata,
        bookIds: _idsFonteSelezionata,
        onFonteSelezionata: (titolo, ids) {
          setState(() {
            _titoloFonteSelezionata = titolo;
            _idsFonteSelezionata = ids;
          });
        },
      ),
    );
  }

  // --- LOGICA ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    try {
      final extra = GoRouterState.of(context).extra;

      if (extra is BookModel && extra != _operaRiconosciutaAR) {
        _operaRiconosciutaAR = extra;

        final isDifferent =
            _idsFonteSelezionata == null ||
            !_idsFonteSelezionata!.contains(extra.id);

        if (isDifferent) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _titoloFonteSelezionata = extra.titolo;
                _idsFonteSelezionata = [extra.id];
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint(
        '[ChatScreen] Impossibile recuperare GoRouterState '
        'in didChangeDependencies: $e',
      );
    }
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
}
