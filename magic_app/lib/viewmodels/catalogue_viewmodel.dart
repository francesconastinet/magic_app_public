import 'package:flutter/foundation.dart';
import '../core/app_state.dart';
import '../data/catalogue_repository.dart';
import '../data/models.dart';

class CatalogueViewModel extends ChangeNotifier {
  // --- DIPENDENZE ---
  final AppState _appState;
  final CatalogueRepository _repository;
  final Set<String> _initialSelectedIds;

  // --- STATO ---
  String _searchQuery = '';
  Set<String> selectedBookIds = {};
  String? selectedCollectionId;

  CatalogueViewModel({
    required this._appState,
    required this._repository,
    List<String>? initialIds,
  }) : _initialSelectedIds = Set<String>.from(initialIds ?? []) {
    selectedBookIds = Set<String>.from(initialIds ?? []);

    _appState.addListener(notifyListeners);
    _repository.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _appState.removeListener(notifyListeners);
    _repository.removeListener(notifyListeners);
    super.dispose();
  }

  // --- GETTER ---
  bool get isSyncing => _appState.isSyncing;
  // true mentre si scaricano i libri della collezione selezionata
  bool get isLoadingLibriCollezione => _repository.isLoadingLibri;
  List<CollectionV2Model> get collezioni => _repository.collezioni;
  List<BookModel> get tuttiILibri => _repository.libri;
  String get searchQuery => _searchQuery;

  // i libri di una collezione sono quelli che hanno collection_id uguale
  // all'id della collezione (GET /api/collections/public/magic/). Prima si
  // usava la lista bookIds scritta dentro la collezione (percorso medievale).
  List<String> idsLibriCollezione(String collectionId) {
    if (collectionId.isEmpty) return [];
    return tuttiILibri
        .where((o) => o.collectionId == collectionId)
        .map((o) => o.id)
        .toList();
  }

  List<BookModel> get opereFiltrate {
    var filtrate = tuttiILibri.toList();

    if (selectedCollectionId != null) {
      // filtro per collezione tramite il collection_id del libro
      filtrate = filtrate
          .where((o) => o.collectionId == selectedCollectionId)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtrate = filtrate
          .where(
            (o) =>
                o.titolo.toLowerCase().contains(query) ||
                o.autore.toLowerCase().contains(query),
          )
          .toList();
    }

    filtrate.sort((a, b) {
      final aSelezionato = _initialSelectedIds.contains(a.id);
      final bSelezionato = _initialSelectedIds.contains(b.id);
      if (aSelezionato && !bSelezionato) return -1;
      if (!aSelezionato && bSelezionato) return 1;
      return a.titolo.compareTo(b.titolo);
    });

    return filtrate;
  }

  // --- LOGICA ---

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  void setCollection(String? id) {
    selectedCollectionId = id;
    notifyListeners();

    // quando si sceglie una collezione si scaricano i suoi libri da
    // GET /api/documents/search/v2/{tenant_id}/ con il collection_id
    if (id != null) {
      _repository.caricaLibriCollezione(id);
    }
  }

  void toggleBook(String id, bool isSelected) {
    if (isSelected) {
      selectedBookIds.add(id);
    } else {
      selectedBookIds.remove(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    selectedBookIds.clear();
    notifyListeners();
  }

  void toggleCollectionSelection(CollectionV2Model collezione) {
    final idsCollezione = idsLibriCollezione(collezione.id);

    bool allSelected =
        idsCollezione.isNotEmpty &&
        idsCollezione.every((id) => selectedBookIds.contains(id));

    if (allSelected) {
      selectedBookIds.removeAll(idsCollezione);
    } else {
      selectedBookIds.addAll(idsCollezione);
    }
    notifyListeners();
  }

  // collection_id da mandare nella /query del chatbot. Si manda solo se
  // tutti i libri selezionati appartengono alla stessa collezione; se non c'e'
  // selezione o i libri sono di collezioni diverse resta null e il chatbot
  // risponde su tutto (collection_id facoltativo).
  String? _collectionIdDellaSelezione() {
    if (selectedBookIds.isEmpty) return null;

    String? idComune;
    for (final id in selectedBookIds) {
      String? idCollezioneLibro;
      for (final o in tuttiILibri) {
        if (o.id == id) {
          idCollezioneLibro = o.collectionId;
          break;
        }
      }

      if (idCollezioneLibro == null || idCollezioneLibro.isEmpty) return null;
      if (idComune == null) {
        idComune = idCollezioneLibro;
      } else if (idComune != idCollezioneLibro) {
        return null;
      }
    }
    return idComune;
  }

  void applicaSelezione(
    void Function(String? titolo, List<String>? ids) callback,
    VoidCallback onDone,
  ) {
    // la collezione della selezione viene salvata nello stato dell'app,
    // cosi' la chat la puo' mandare come collection_id nella /query
    final collectionIdChat = _collectionIdDellaSelezione();
    _appState.impostaCollezioneChat(collectionIdChat);
    debugPrint('[CATALOGO] collection_id per la chat: $collectionIdChat');

    if (selectedBookIds.isEmpty) {
      callback(null, null);
    } else if (selectedBookIds.length == 1) {
      final idSingolo = selectedBookIds.first;
      final opera = tuttiILibri.firstWhere((o) => o.id == idSingolo);
      callback(opera.titolo, [idSingolo]);
    } else {
      String? nomeCollezioneCorrispondente;
      for (var coll in collezioni) {
        final idsCollezione = idsLibriCollezione(coll.id);
        if (idsCollezione.length == selectedBookIds.length &&
            idsCollezione.every((id) => selectedBookIds.contains(id))) {
          nomeCollezioneCorrispondente = coll.name;
          break;
        }
      }

      if (nomeCollezioneCorrispondente != null) {
        callback(nomeCollezioneCorrispondente, selectedBookIds.toList());
      } else {
        callback('Manoscritti vari', selectedBookIds.toList());
      }
    }
    onDone();
  }
}