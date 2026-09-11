import 'package:flutter/foundation.dart';
import '../core/app_config.dart';
import '../core/app_state.dart';
import '../data/catalogue_repository.dart';
import '../data/models.dart';
import '../services/auth_service.dart';
import '../services/package_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';

class HomeViewModel extends ChangeNotifier {
  // --- DIPENDENZE ---
  final AppState _appState;
  final StorageService _storage;
  final AuthService _authService;
  final CatalogueRepository _repository;

  // --- STATO ---
  bool syncInCorso = false;
  String? titoloFonteSelezionata;
  List<String>? idsFonteSelezionata;
  BookModel? _operaRiconosciutaAR;

  // --- EVENTI UI ---
  void Function(String)? onShowMessage;

  HomeViewModel({
    required this._appState,
    required this._storage,
    required this._authService,
    required this._repository,
  }) {
    _appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  // --- LOGICA ---

  void inizializza(String? titoloIniziale, List<String>? idsIniziali) {
    titoloFonteSelezionata = titoloIniziale;
    idsFonteSelezionata = idsIniziali;
    _onAppStateChanged();
  }

  void selezionaFonte(String? titolo, List<String>? ids) {
    titoloFonteSelezionata = titolo;
    idsFonteSelezionata = ids;
    _operaRiconosciutaAR = null;
    notifyListeners();
  }

  void _onAppStateChanged() {
    final operaSelezionata = _appState.operaSelezionata;

    if (operaSelezionata != null && operaSelezionata != _operaRiconosciutaAR) {
      final isDifferent =
          idsFonteSelezionata == null ||
          !idsFonteSelezionata!.contains(operaSelezionata.id);

      if (isDifferent) {
        _operaRiconosciutaAR = operaSelezionata;
        titoloFonteSelezionata = operaSelezionata.titolo;
        idsFonteSelezionata = [operaSelezionata.id];
        notifyListeners();
      }
    }
  }

  Future<void> avviaSincronizzazione() async {
    await _repository.caricaDatiLocali();

    try {
      final updateService = UpdateService();
      final necessaria = await updateService.isSincronizzazioneNecessaria(
        AppConfig.packageId,
      );

      if (!necessaria) return;

      syncInCorso = true;
      _appState.setSyncing(true);
      notifyListeners();

      final packageService = PackageService(
        storage: _storage,
        authService: _authService,
      );

      final risultato = await packageService.sincronizzaSeCambiato(
        packageId: AppConfig.packageId,
        versione: 'api-latest',
        onStato: (msg) => debugPrint('[SYNC] $msg'),
      );

      if (risultato.successo && risultato.scaricato) {
        await _repository.caricaDatiLocali();
        onShowMessage?.call('Pacchetto aggiornato con successo');
      } else if (!risultato.successo) {
        onShowMessage?.call(
          'Impossibile scaricare il pacchetto, riprova più tardi',
        );
      }
    } catch (e) {
      debugPrint('[SYNC] Errore sync automatica: $e');
      onShowMessage?.call('Errore di connessione durante l\'aggiornamento');
    } finally {
      syncInCorso = false;
      _appState.setSyncing(false);
      notifyListeners();
    }
  }
}
