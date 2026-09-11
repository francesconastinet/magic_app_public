import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../data/catalogue_repository.dart';
import '../data/models.dart';

// ==========================================
// SCHERMATA
// ==========================================

class CatalogueWidget extends StatefulWidget {
  final void Function(String? titolo, List<String>? ids) onFonteSelezionata;
  final List<String>? idsFonteIniziale;

  const CatalogueWidget({
    super.key,
    required this.onFonteSelezionata,
    this.idsFonteIniziale,
  });

  @override
  State<CatalogueWidget> createState() => _CatalogueWidgetState();
}

class _CatalogueWidgetState extends State<CatalogueWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Set<String> _selectedBookIds;
  String? _selectedCollectionId;

  @override
  void initState() {
    super.initState();
    _selectedBookIds = Set<String>.from(widget.idsFonteIniziale ?? []);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSyncing = context.watch<AppState>().isSyncing;
    final repo = context.watch<CatalogueRepository>();
    final collezioni = repo.collezioni;
    final tuttiILibri = repo.libri;
    var opereFiltrate = tuttiILibri.toList();
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    if (_selectedCollectionId != null) {
      final activeColl = collezioni.firstWhere(
        (c) => c.id == _selectedCollectionId,
        orElse: () =>
            CollectionV2Model(id: '', name: '', description: '', bookIds: []),
      );
      opereFiltrate = opereFiltrate
          .where((o) => activeColl.bookIds.contains(o.id))
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      opereFiltrate = opereFiltrate
          .where(
            (o) =>
                o.titolo.toLowerCase().contains(query) ||
                o.autore.toLowerCase().contains(query),
          )
          .toList();
    }

    final initialSelectedIds = Set<String>.from(widget.idsFonteIniziale ?? []);
    opereFiltrate.sort((a, b) {
      final aSelezionato = initialSelectedIds.contains(a.id);
      final bSelezionato = initialSelectedIds.contains(b.id);
      if (aSelezionato && !bSelezionato) return -1;
      if (!aSelezionato && bSelezionato) return 1;
      return a.titolo.compareTo(b.titolo);
    });

    return FractionallySizedBox(
      heightFactor: isLandscape ? (isTablet ? 0.8 : 1) : 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FontiHeaderSection(
            onReset: () => setState(() => _selectedBookIds.clear()),
            onClose: () {
              if (context.canPop()) context.pop();
            },
            haSelezioni: _selectedBookIds.isNotEmpty,
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
                  collezioni: collezioni,
                  selectedCollectionId: _selectedCollectionId,
                  onCollectionSelected: (id) =>
                      setState(() => _selectedCollectionId = id),
                ),
                if (_selectedCollectionId != null && opereFiltrate.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Builder(
                      builder: (context) {
                        final activeColl = collezioni.firstWhere(
                          (c) => c.id == _selectedCollectionId,
                        );

                        final allSelected =
                            activeColl.bookIds.isNotEmpty &&
                            activeColl.bookIds.every(
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

                if (isSyncing)
                  const FontiDownloadingMessage()
                else if (tuttiILibri.isEmpty)
                  const FontiEmptyCatalogMessage()
                else if (opereFiltrate.isEmpty)
                  const FontiEmptySearchResults()
                else
                  FontiBooksSection(
                    opere: opereFiltrate,
                    selectedBookIds: _selectedBookIds,
                    onBookToggled: (id, isSelected) {
                      setState(() {
                        isSelected
                            ? _selectedBookIds.add(id)
                            : _selectedBookIds.remove(id);
                      });
                    },
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

  void _applicaSelezione() {
    final repo = context.read<CatalogueRepository>();

    if (_selectedBookIds.isEmpty) {
      widget.onFonteSelezionata(null, null);
    } else if (_selectedBookIds.length == 1) {
      final idSingolo = _selectedBookIds.first;
      final opera = repo.libri.firstWhere((o) => o.id == idSingolo);
      widget.onFonteSelezionata(opera.titolo, [idSingolo]);
    } else {
      String? nomeCollezioneCorrispondente;
      for (var coll in repo.collezioni) {
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
        widget.onFonteSelezionata(
          'Manoscritti vari',
          _selectedBookIds.toList(),
        );
      }
    }
    if (context.canPop()) context.pop();
  }

  void _toggleCollectionSelection(CollectionV2Model collezione) {
    setState(() {
      bool allSelected =
          collezione.bookIds.isNotEmpty &&
          collezione.bookIds.every((id) => _selectedBookIds.contains(id));

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
                icon: const Icon(Icons.deselect, size: 14),
                label: const Text(
                  'Annulla selezione',
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
  final List<CollectionV2Model> collezioni;
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

    if (collezioni.isEmpty) return const SizedBox.shrink();

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
  }
}

// --- SEZIONE MANOSCRITTI ---
class FontiBooksSection extends StatelessWidget {
  final List<dynamic> opere;
  final Set<String> selectedBookIds;
  final void Function(String id, bool isSelected) onBookToggled;

  const FontiBooksSection({
    super.key,
    required this.opere,
    required this.selectedBookIds,
    required this.onBookToggled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                    final router = GoRouter.of(context);
                    router.pop();
                    router.push('/opera/${opera.id}', extra: opera);
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
  }
}

// --- NESSUN RISULTATO RICERCA ---
class FontiEmptySearchResults extends StatelessWidget {
  const FontiEmptySearchResults({super.key});

  @override
  Widget build(BuildContext context) {
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
}

// --- CATALOGO VUOTO ---
class FontiEmptyCatalogMessage extends StatelessWidget {
  const FontiEmptyCatalogMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Text(
          'Il catalogo è vuoto.\nNon ci sono manoscritti disponibili al momento.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// --- DOWNLOAD IN CORSO ---
class FontiDownloadingMessage extends StatelessWidget {
  const FontiDownloadingMessage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Sincronizzazione in corso...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sto scaricando i manoscritti dal server.\nAttendere prego.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
