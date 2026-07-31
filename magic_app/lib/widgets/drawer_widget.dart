import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../services/chat_service.dart';
import '../models.dart';
import '../opera_repository.dart';

// ==========================================
// SCHERMATA
// ==========================================

class DrawerWidget extends StatefulWidget {
  final String? titoloFonteAttuale;
  final void Function(String? titolo, List<String>? ids) onFonteSelezionata;

  const DrawerWidget({
    super.key,
    required this.titoloFonteAttuale,
    required this.onFonteSelezionata,
  });

  @override
  State<DrawerWidget> createState() => _DrawerWidgetState();
}

class _DrawerWidgetState extends State<DrawerWidget> {
  late Future<List<CollectionV2Model>> _collezioniFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // TODO; rimuovere quando disponibile login
  static String? _mockLoggedUser;

  @override
  void initState() {
    super.initState();

    // TODO: modificare quando disponibile dataset
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
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DrawerHeaderSection(
              titoloFonteAttuale: widget.titoloFonteAttuale,
              onReset: () {
                widget.onFonteSelezionata(null, null);
                Navigator.pop(context);
              },
            ),

            DrawerSearchBar(
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
                  CollectionsSection(
                    collezioniFuture: _collezioniFuture,
                    searchQuery: _searchQuery,
                    onFonteSelezionata: widget.onFonteSelezionata,
                  ),

                  BooksSection(
                    searchQuery: _searchQuery,
                    onFonteSelezionata: widget.onFonteSelezionata,
                  ),

                  EmptySearchResults(
                    collezioniFuture: _collezioniFuture,
                    searchQuery: _searchQuery,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            DrawerSectionTitle(titolo: 'Chat'),

            const ShareChatTile(),

            const RestoreChatTile(),

            const Divider(height: 1),

            DrawerSectionTitle(titolo: 'Profilo'),

            ProfileSection(
              mockLoggedUser: _mockLoggedUser,
              onLogin: (user) {
                setState(() => _mockLoggedUser = user);
                Navigator.pop(context);
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
              onLogout: () {
                setState(() => _mockLoggedUser = null);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logout effettuato')),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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

// --- TITOLO SEZIONE GENERICA ---
class DrawerSectionTitle extends StatelessWidget {
  final String titolo;

  const DrawerSectionTitle({super.key, required this.titolo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        titolo,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// --- HEADER FONTI ---
class DrawerHeaderSection extends StatelessWidget {
  final String? titoloFonteAttuale;
  final VoidCallback onReset;

  const DrawerHeaderSection({
    super.key,
    required this.titoloFonteAttuale,
    required this.onReset,
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
          Text(
            'Fonti Disponibili',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
            ),
          ),

          if (titoloFonteAttuale != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.lock_open, size: 14),
                label: const Text(
                  'Sblocca le fonti',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
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
class DrawerSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const DrawerSearchBar({
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
          hintText: 'Cerca una fonte...',
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

// --- SEZIONE COLLEZIONI ---
class CollectionsSection extends StatelessWidget {
  final Future<List<CollectionV2Model>> collezioniFuture;
  final String searchQuery;
  final void Function(String? titolo, List<String>? ids) onFonteSelezionata;

  const CollectionsSection({
    super.key,
    required this.collezioniFuture,
    required this.searchQuery,
    required this.onFonteSelezionata,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<CollectionV2Model>>(
      future: collezioniFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        var collezioni = snapshot.data ?? [];

        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
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
                  onFonteSelezionata(collection.name, collection.bookIds);
                },
              ),
            ),

            const Divider(),
          ],
        );
      },
    );
  }
}

// --- SEZIONE LIBRI ---
class BooksSection extends StatelessWidget {
  final String searchQuery;
  final void Function(String? titolo, List<String>? ids) onFonteSelezionata;

  const BooksSection({
    super.key,
    required this.searchQuery,
    required this.onFonteSelezionata,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // TODO: modificare quando disponibile dataset
    var opere = OperaRepository.tutteLeOpere();

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
              onFonteSelezionata(opera.titolo, [opera.id]);
            },
          ),
        ),
      ],
    );
  }
}

// --- NESSUN RISULTATO RICERCA ---
class EmptySearchResults extends StatelessWidget {
  final Future<List<CollectionV2Model>> collezioniFuture;
  final String searchQuery;

  const EmptySearchResults({
    super.key,
    required this.collezioniFuture,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<CollectionV2Model>>(
      future: collezioniFuture,
      builder: (context, snapshot) {
        final collezioni = snapshot.data ?? [];
        final query = searchQuery.toLowerCase();
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

// --- Pulsante: CONDIVIDI CHAT ---
class ShareChatTile extends StatelessWidget {
  const ShareChatTile({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      leading: Icon(Icons.mobile_screen_share, color: colorScheme.primary),
      title: const Text('Condividi Chat'),
      onTap: () async {
        final chatService = context.read<ChatService>();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );

        final codice = await chatService.generaCodiceCondivisione();

        if (!context.mounted) return;
        Navigator.pop(context); // Chiude il loader

        if (codice != null) {
          showDialog(
            context: context,
            builder: (ctx) => ShareCodeDialog(codice: codice),
          );
        }
      },
    );
  }
}

// --- DIALOG: CONDIVISIONE CODICE ---
class ShareCodeDialog extends StatefulWidget {
  final String codice;
  const ShareCodeDialog({super.key, required this.codice});

  @override
  State<ShareCodeDialog> createState() => _ShareCodeDialogState();
}

class _ShareCodeDialogState extends State<ShareCodeDialog> {
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
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
            padding: EdgeInsets.only(top: 8.0, bottom: 24.0),
            child: Text(
              'Usa questo codice per continuare la '
              'conversazione su un altro dispositivo:',
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
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
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.codice,
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
                          ClipboardData(text: widget.codice),
                        );

                        if (!mounted) return;
                        setState(() => _isCopied = true);

                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _isCopied = false);
                        });
                      },
                    ),
                  ],
                ),
              ),

              Positioned(
                top: -24,
                right: -10,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _isCopied ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check, color: Colors.white, size: 14),

                          SizedBox(width: 6),

                          Text(
                            'Copiato',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi'),
        ),
      ],
    );
  }
}

// --- PULSANTE: RIPRISTINA CHAT ---
class RestoreChatTile extends StatelessWidget {
  const RestoreChatTile({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      leading: Icon(Icons.settings_backup_restore, color: colorScheme.primary),
      title: const Text('Ripristina Chat'),
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => const RestoreChatDialog(),
        );
      },
    );
  }
}

// --- DIALOG: RIPRISTINA CHAT ---
class RestoreChatDialog extends StatefulWidget {
  const RestoreChatDialog({super.key});

  @override
  State<RestoreChatDialog> createState() => _RestoreChatDialogState();
}

class _RestoreChatDialogState extends State<RestoreChatDialog> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
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
            const Text('Usa un codice per continuare una conversazione.'),

            const SizedBox(height: 16),

            TextField(
              controller: _codeController,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Codice di 6 caratteri',
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),

        FilledButton(
          onPressed: () async {
            final codice = _codeController.text.trim();
            if (codice.length != 6) return;

            Navigator.pop(context);

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(child: CircularProgressIndicator()),
            );

            final successo = await context
                .read<ChatService>()
                .ripristinaSessione(codice);

            if (!context.mounted) return;

            Navigator.pop(context);
            Navigator.pop(context);

            if (successo) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sessione ripristinata con successo!'),
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
    );
  }
}

// --- SEZIONE PROFILO ---
class ProfileSection extends StatelessWidget {
  final String? mockLoggedUser;
  final ValueChanged<String> onLogin;
  final VoidCallback onLogout;

  const ProfileSection({
    super.key,
    required this.mockLoggedUser,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (mockLoggedUser != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  mockLoggedUser!,
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
              onPressed: onLogout,
            ),
          ],
        ),
      );
    }

    return ListTile(
      dense: true,
      leading: Icon(Icons.login, color: colorScheme.primary),
      title: const Text('Accedi / Registrati'),
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => LoginDialog(onLogin: onLogin),
        );
      },
    );
  }
}

// --- MOCK LOGIN ---
class LoginDialog extends StatefulWidget {
  final ValueChanged<String> onLogin;

  const LoginDialog({super.key, required this.onLogin});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
              controller: _userCtrl,
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
              controller: _passCtrl,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),

        FilledButton(
          onPressed: _isLoading
              ? null
              : () async {
                  final user = _userCtrl.text.trim();
                  if (user.isEmpty) return;

                  setState(() => _isLoading = true);

                  if (!mounted) return;
                  Navigator.pop(context);
                  widget.onLogin(user);
                },
          child: _isLoading
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
  }
}
