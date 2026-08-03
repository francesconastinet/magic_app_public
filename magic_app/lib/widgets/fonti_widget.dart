import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../opera_repository.dart';

// ==========================================
// SCHERMATA
// ==========================================

class FontiSelectionSheet extends StatefulWidget {
  final String? titoloFonteAttuale;
  final void Function(String? titolo, List<String>? ids) onFonteSelezionata;

  const FontiSelectionSheet({
    super.key,
    required this.titoloFonteAttuale,
    required this.onFonteSelezionata,
  });

  @override
  State<FontiSelectionSheet> createState() => _FontiSelectionSheetState();
}

class _FontiSelectionSheetState extends State<FontiSelectionSheet> {
  late Future<List<CollectionV2Model>> _collezioniFuture;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedCollectionId;

  @override
  void initState() {
    super.initState();
    // TODO: modificare quando disponibile dataset (come nel vecchio drawer)
    _collezioniFuture = _caricaCollezioni();
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
      heightFactor: 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FontiHeaderSection(
            titoloFonteAttuale: widget.titoloFonteAttuale,
            onReset: () {
              widget.onFonteSelezionata(null, null);
              Navigator.pop(context);
            },
            onClose: () => Navigator.pop(context),
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
                  collezioniFuture: _collezioniFuture,
                  selectedCollectionId: _selectedCollectionId,
                  onCollectionSelected: (id) {
                    setState(() => _selectedCollectionId = id);
                  },
                ),

                FontiBooksSection(
                  searchQuery: _searchQuery,
                  selectedCollectionId: _selectedCollectionId,
                  titoloFonteAttuale: widget.titoloFonteAttuale,
                  collezioniFuture: _collezioniFuture,
                  onFonteSelezionata: widget.onFonteSelezionata,
                ),

                FontiEmptySearchResults(
                  searchQuery: _searchQuery,
                  selectedCollectionId: _selectedCollectionId,
                  collezioniFuture: _collezioniFuture,
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
}

// ==========================================
// WIDGET
// ==========================================

// --- HEADER FONTI ---
class FontiHeaderSection extends StatelessWidget {
  final String? titoloFonteAttuale;
  final VoidCallback onReset;
  final VoidCallback onClose;

  const FontiHeaderSection({
    super.key,
    required this.titoloFonteAttuale,
    required this.onReset,
    required this.onClose,
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

          if (titoloFonteAttuale != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.lock_open, size: 14),
                label: const Text(
                  'Sblocca le fonti',
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
  final Future<List<CollectionV2Model>> collezioniFuture;
  final String? selectedCollectionId;
  final ValueChanged<String?> onCollectionSelected;

  const FontiCollectionsSection({
    super.key,
    required this.collezioniFuture,
    required this.selectedCollectionId,
    required this.onCollectionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<CollectionV2Model>>(
      future: collezioniFuture,
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
  final String? titoloFonteAttuale;
  final Future<List<CollectionV2Model>> collezioniFuture;
  final void Function(String? titolo, List<String>? ids) onFonteSelezionata;

  const FontiBooksSection({
    super.key,
    required this.searchQuery,
    required this.selectedCollectionId,
    required this.titoloFonteAttuale,
    required this.collezioniFuture,
    required this.onFonteSelezionata,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<CollectionV2Model>>(
      future: collezioniFuture,
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

        if (titoloFonteAttuale != null) {
          opere.sort((a, b) {
            if (a.titolo == titoloFonteAttuale) return -1;
            if (b.titolo == titoloFonteAttuale) return 1;
            return 0;
          });
        }

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
              final isAttiva = opera.titolo == titoloFonteAttuale;

              return ListTile(
                leading: Icon(
                  Icons.menu_book,
                  color: isAttiva ? colorScheme.primary : null,
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
                trailing: isAttiva
                    ? Icon(
                        Icons.check_circle,
                        color: colorScheme.primary,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  context.read<AppState>().selezionaOpera(opera);
                  Navigator.pop(context);
                  onFonteSelezionata(opera.titolo, [opera.id]);
                },
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
  final Future<List<CollectionV2Model>> collezioniFuture;

  const FontiEmptySearchResults({
    super.key,
    required this.searchQuery,
    required this.selectedCollectionId,
    required this.collezioniFuture,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CollectionV2Model>>(
      future: collezioniFuture,
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
