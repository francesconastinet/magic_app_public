import 'package:flutter/material.dart';
import '../models.dart';
import '../opera_repository.dart'; // TODO: rimuovere opere hardcodate
import '../screens/book_detail_screen.dart';

// ==========================================
// SCHERMATA
// ==========================================

class FontiSelectionSheet extends StatefulWidget {
  final void Function(String? titolo, List<String>? ids) onFonteSelezionata;
  final List<String>? idsFonteIniziale;

  const FontiSelectionSheet({
    super.key,
    required this.onFonteSelezionata,
    this.idsFonteIniziale,
  });

  @override
  State<FontiSelectionSheet> createState() => _FontiSelectionSheetState();
}

class _FontiSelectionSheetState extends State<FontiSelectionSheet> {
  late Future<List<CollectionV2Model>> _collezioni;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late Set<String> _selectedBookIds;
  String? _selectedCollectionId;
  List<CollectionV2Model> _collezioniCache = [];

  @override
  void initState() {
    super.initState();
    _selectedBookIds = Set<String>.from(widget.idsFonteIniziale ?? []);

    // TODO: modificare quando disponibile dataset
    _collezioni = _caricaCollezioni().then((collezioni) {
      _collezioniCache = collezioni;
      return collezioni;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FontiHeaderSection(
            onReset: () {
              setState(() => _selectedBookIds.clear());
              widget.onFonteSelezionata(null, null);
              Navigator.pop(context);
            },
            onClose: () => Navigator.pop(context),
            haSelezioni:
                widget.idsFonteIniziale != null &&
                widget.idsFonteIniziale!.isNotEmpty,
          ),

          FontiSearchBar(
            controller: _searchController,
            searchQuery: _searchQuery,
            onChanged: (value) => setState(() => _searchQuery = value),
            onClear: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                FontiCollectionsSection(
                  collezioni: _collezioni,
                  selectedCollectionId: _selectedCollectionId,
                  onCollectionSelected: (id) {
                    setState(() => _selectedCollectionId = id);
                  },
                ),

                if (_selectedCollectionId != null &&
                    _collezioniCache.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Builder(
                      builder: (context) {
                        final activeColl = _collezioniCache.firstWhere(
                          (c) => c.id == _selectedCollectionId,
                        );

                        final allSelected = activeColl.bookIds.every(
                          (id) => _selectedBookIds.contains(id),
                        );

                        return OutlinedButton.icon(
                          icon: Icon(
                            allSelected ? Icons.deselect : Icons.select_all,
                          ),
                          label: Text(
                            allSelected
                                ? 'Deseleziona tutta la collezione'
                                : 'Seleziona tutta la collezione',
                          ),
                          onPressed: () =>
                              _toggleCollectionSelection(activeColl),
                        );
                      },
                    ),
                  ),

                FontiBooksSection(
                  searchQuery: _searchQuery,
                  selectedCollectionId: _selectedCollectionId,
                  selectedBookIds: _selectedBookIds,
                  collezioni: _collezioni,
                  onBookToggled: (id, isSelected) {
                    setState(() {
                      if (isSelected) {
                        _selectedBookIds.add(id);
                      } else {
                        _selectedBookIds.remove(id);
                      }
                    });
                  },
                ),

                FontiEmptySearchResults(
                  searchQuery: _searchQuery,
                  selectedCollectionId: _selectedCollectionId,
                  collezioni: _collezioni,
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedBookIds.length} selezionati',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                FilledButton(
                  onPressed: _applicaSelezione,
                  child: const Text('Applica'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- LOGICA ---
  Future<List<CollectionV2Model>> _caricaCollezioni() async {
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

  void _applicaSelezione() {
    if (_selectedBookIds.isEmpty) {
      widget.onFonteSelezionata(null, null);
    } else if (_selectedBookIds.length == 1) {
      final idSingolo = _selectedBookIds.first;
      final opera = OperaRepository.tutteLeOpere().firstWhere(
        (o) => o.id == idSingolo,
      );
      widget.onFonteSelezionata(opera.titolo, [idSingolo]);
    } else {
      String? nomeCollezioneCorrispondente;
      for (var coll in _collezioniCache) {
        if (coll.bookIds.length == _selectedBookIds.length &&
            coll.bookIds.every((id) => _selectedBookIds.contains(id))) {
          nomeCollezioneCorrispondente = coll.name;
          break;
        }
      }
      if (nomeCollezioneCorrispondente != null) {
        widget.onFonteSelezionata(
          nomeCollezioneCorrispondente,
          _selectedBookIds.toList(),
        );
      } else {
        widget.onFonteSelezionata('Miscellanea', _selectedBookIds.toList());
      }
    }

    Navigator.pop(context);
  }

  void _toggleCollectionSelection(CollectionV2Model collezione) {
    setState(() {
      bool allSelected = collezione.bookIds.every(
        (id) => _selectedBookIds.contains(id),
      );
      if (allSelected) {
        _selectedBookIds.removeAll(collezione.bookIds);
      } else {
        _selectedBookIds.addAll(collezione.bookIds);
      }
    });
  }
}

// ==========================================
// WIDGET
// ==========================================

// --- HEADER FONTI ---
class FontiHeaderSection extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onClose;
  final bool haSelezioni;

  const FontiHeaderSection({
    super.key,
    required this.onReset,
    required this.onClose,
    required this.haSelezioni,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Manoscritti',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          if (haSelezioni)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text(
                  'Modalità Smart',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: colorScheme.primary,
                  backgroundColor: colorScheme.surface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- BARRA DI RICERCA ---
class FontiSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const FontiSearchBar({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Cerca un manoscritto...',
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: onClear,
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
        onChanged: onChanged,
      ),
    );
  }
}

// --- FILTRO COLLEZIONI ---
class FontiCollectionsSection extends StatelessWidget {
  final Future<List<CollectionV2Model>> collezioni;
  final String? selectedCollectionId;
  final ValueChanged<String?> onCollectionSelected;

  const FontiCollectionsSection({
    super.key,
    required this.collezioni,
    required this.selectedCollectionId,
    required this.onCollectionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<CollectionV2Model>>(
      future: this.collezioni,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 50,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final collezioni = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Filtra per Collezione',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: const Text('Tutti i manoscritti'),
                      selected: selectedCollectionId == null,
                      onSelected: (selected) {
                        if (selected) onCollectionSelected(null);
                      },
                    ),
                  ),
                  ...collezioni.map(
                    (collection) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(collection.name),
                        selected: selectedCollectionId == collection.id,
                        onSelected: (selected) {
                          if (selected) onCollectionSelected(collection.id);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(height: 1),
            ),
          ],
        );
      },
    );
  }
}

// --- SEZIONE MANOSCRITTI ---
class FontiBooksSection extends StatelessWidget {
  final String searchQuery;
  final String? selectedCollectionId;
  final Set<String> selectedBookIds;
  final Future<List<CollectionV2Model>> collezioni;
  final void Function(String id, bool isSelected) onBookToggled;

  const FontiBooksSection({
    super.key,
    required this.searchQuery,
    required this.selectedCollectionId,
    required this.selectedBookIds,
    required this.collezioni,
    required this.onBookToggled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<CollectionV2Model>>(
      future: collezioni,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        var opere = OperaRepository.tutteLeOpere();

        if (selectedCollectionId != null) {
          final collezioneSelezionata = snapshot.data!.firstWhere(
            (c) => c.id == selectedCollectionId,
            orElse: () => CollectionV2Model(
              id: '',
              name: '',
              description: '',
              bookIds: [],
            ),
          );
          opere = opere
              .where((o) => collezioneSelezionata.bookIds.contains(o.id))
              .toList();
        }

        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
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
                'Risultati',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...opere.map((opera) {
              final isAttiva = selectedBookIds.contains(opera.id);

              return CheckboxListTile(
                secondary: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      tooltip: 'Dettagli Manoscritto',
                      color: colorScheme.primary,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookDetailScreen(book: opera),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                title: Text(
                  opera.titolo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isAttiva ? FontWeight.bold : FontWeight.normal,
                    color: isAttiva ? colorScheme.primary : null,
                  ),
                ),
                subtitle: Text(
                  opera.autore,
                  style: TextStyle(
                    fontSize: 12,
                    color: isAttiva
                        ? colorScheme.primary.withValues(alpha: 0.8)
                        : null,
                  ),
                ),
                value: isAttiva,
                onChanged: (bool? value) {
                  onBookToggled(opera.id, value ?? false);
                },
                controlAffinity: ListTileControlAffinity.trailing,
              );
            }),
          ],
        );
      },
    );
  }
}

// --- NESSUN RISULTATO RICERCA ---
class FontiEmptySearchResults extends StatelessWidget {
  final String searchQuery;
  final String? selectedCollectionId;
  final Future<List<CollectionV2Model>> collezioni;

  const FontiEmptySearchResults({
    super.key,
    required this.searchQuery,
    required this.selectedCollectionId,
    required this.collezioni,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CollectionV2Model>>(
      future: collezioni,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        var opere = OperaRepository.tutteLeOpere();

        if (selectedCollectionId != null) {
          final coll = snapshot.data!.firstWhere(
            (c) => c.id == selectedCollectionId,
            orElse: () => CollectionV2Model(
              id: '',
              name: '',
              description: '',
              bookIds: [],
            ),
          );
          opere = opere.where((o) => coll.bookIds.contains(o.id)).toList();
        }

        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          opere = opere
              .where(
                (o) =>
                    o.titolo.toLowerCase().contains(query) ||
                    o.autore.toLowerCase().contains(query),
              )
              .toList();
        }

        if (opere.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                'Nessun manoscritto trovato.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
