import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../data/catalogue_repository.dart';
import '../data/models.dart';
import '../viewmodels/catalogue_viewmodel.dart';

// ==========================================
// SCHERMATA
// ==========================================

class CatalogueView extends StatefulWidget {
  final void Function(String? titolo, List<String>? ids) onFonteSelezionata;
  final List<String>? idsFonteIniziale;

  const CatalogueView({
    super.key,
    required this.onFonteSelezionata,
    this.idsFonteIniziale,
  });

  @override
  State<CatalogueView> createState() => _CatalogueViewState();
}

class _CatalogueViewState extends State<CatalogueView> {
  late CatalogueViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = CatalogueViewModel(
      appState: context.read<AppState>(),
      repository: context.read<CatalogueRepository>(),
      initialIds: widget.idsFonteIniziale,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<CatalogueViewModel>(
        builder: (context, vm, child) {
          return FractionallySizedBox(
            heightFactor: isLandscape ? (isTablet ? 0.8 : 1) : 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FontiHeaderSection(
                  onReset: vm.clearSelection,
                  onClose: () {
                    if (context.canPop()) context.pop();
                  },
                  haSelezioni: vm.selectedBookIds.isNotEmpty,
                ),
                FontiSearchBar(
                  controller: _searchController,
                  searchQuery: vm.searchQuery,
                  onChanged: vm.setSearchQuery,
                  onClear: () {
                    _searchController.clear();
                    vm.clearSearch();
                  },
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      FontiCollectionsSection(
                        collezioni: vm.collezioni,
                        selectedCollectionId: vm.selectedCollectionId,
                        onCollectionSelected: vm.setCollection,
                      ),

                      if (vm.selectedCollectionId != null &&
                          vm.opereFiltrate.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Builder(
                            builder: (context) {
                              final activeColl = vm.collezioni.firstWhere(
                                (c) => c.id == vm.selectedCollectionId,
                              );

                              final allSelected =
                                  activeColl.bookIds.isNotEmpty &&
                                  activeColl.bookIds.every(
                                    (id) => vm.selectedBookIds.contains(id),
                                  );

                              return OutlinedButton.icon(
                                icon: Icon(
                                  allSelected
                                      ? Icons.deselect
                                      : Icons.select_all,
                                ),
                                label: Text(
                                  allSelected
                                      ? 'Deseleziona tutta la collezione'
                                      : 'Seleziona tutta la collezione',
                                ),
                                onPressed: () =>
                                    vm.toggleCollectionSelection(activeColl),
                              );
                            },
                          ),
                        ),

                      if (vm.isSyncing && vm.tuttiILibri.isEmpty)
                        const FontiDownloadingMessage()
                      else if (vm.tuttiILibri.isEmpty)
                        const FontiEmptyCatalogMessage()
                      else if (vm.opereFiltrate.isEmpty)
                        const FontiEmptySearchResults()
                      else
                        FontiBooksSection(
                          opere: vm.opereFiltrate,
                          selectedBookIds: vm.selectedBookIds,
                          onBookToggled: vm.toggleBook,
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
                        '${vm.selectedBookIds.length} selezionati',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      FilledButton(
                        onPressed: () {
                          vm.applicaSelezione(widget.onFonteSelezionata, () {
                            if (context.canPop()) context.pop();
                          });
                        },
                        child: const Text('Applica'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
                'Catalogo',
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
  final List<BookModel> opere;
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
                    Future.microtask(
                      () => router.push('/opera/${opera.id}', extra: opera),
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
