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
  List<CollectionV2Model> get collezioni => _repository.collezioni;
  List<BookModel> get tuttiILibri => _repository.libri;
  String get searchQuery => _searchQuery;

  List<BookModel> get opereFiltrate {
    var filtrate = tuttiILibri.toList();

    if (selectedCollectionId != null) {
      final activeColl = collezioni.firstWhere(
        (c) => c.id == selectedCollectionId,
        orElse: () =>
            CollectionV2Model(id: '', name: '', description: '', bookIds: []),
      );
      filtrate = filtrate
          .where((o) => activeColl.bookIds.contains(o.id))
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
    bool allSelected =
        collezione.bookIds.isNotEmpty &&
        collezione.bookIds.every((id) => selectedBookIds.contains(id));

    if (allSelected) {
      selectedBookIds.removeAll(collezione.bookIds);
    } else {
      selectedBookIds.addAll(collezione.bookIds);
    }
    notifyListeners();
  }

  void applicaSelezione(
    void Function(String? titolo, List<String>? ids) callback,
    VoidCallback onDone,
  ) {
    if (selectedBookIds.isEmpty) {
      callback(null, null);
    } else if (selectedBookIds.length == 1) {
      final idSingolo = selectedBookIds.first;
      final opera = tuttiILibri.firstWhere((o) => o.id == idSingolo);
      callback(opera.titolo, [idSingolo]);
    } else {
      String? nomeCollezioneCorrispondente;
      for (var coll in collezioni) {
        if (coll.bookIds.length == selectedBookIds.length &&
            coll.bookIds.every((id) => selectedBookIds.contains(id))) {
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
