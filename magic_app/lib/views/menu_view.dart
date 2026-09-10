import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../viewmodels/menu_viewmodel.dart';

// ==========================================
// SCHERMATA
// ==========================================

class MenuView extends StatefulWidget {
  const MenuView({super.key});

  @override
  State<MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends State<MenuView> {
  late MenuViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = MenuViewModel(chatService: context.read<ChatService>());

    _viewModel.onShowMessage = (msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    };
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);

    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<MenuViewModel>(
        builder: (context, vm, child) {
          return Drawer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: safePadding.top + 24,
                    bottom: 24,
                    left: 16,
                    right: 16,
                  ),
                  color: Colors.white,
                  child: Center(
                    child: Image.asset(
                      'assets/magic-logo.png',
                      height: 40,
                      fit: BoxFit.contain,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                const Spacer(),

                Material(
                  color: Colors.white,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: safePadding.bottom + 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShareChatTile(onShare: vm.condividiStanza),

                        RestoreChatTile(onRestore: vm.collegatiAStanza),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(height: 1),
                        ),

                        ProfileSection(
                          mockLoggedUser: vm.mockLoggedUser,
                          onLogin: (user) {
                            Navigator.pop(context);
                            vm.login(user);
                          },
                          onLogout: () {
                            Navigator.pop(context);
                            vm.logout();
                          },
                        ),
                      ],
                    ),
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

// --- PULSANTE: CONDIVISIONE STANZA ---
class ShareChatTile extends StatelessWidget {
  final Future<String?> Function() onShare;

  const ShareChatTile({super.key, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      leading: Icon(Icons.mobile_screen_share, color: colorScheme.primary),
      title: const Text('Condividi la stanza'),
      onTap: () async {
        final navigator = Navigator.of(context, rootNavigator: true);
        navigator.pop();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );

        final codice = await onShare();

        navigator.pop();

        if (codice != null && navigator.context.mounted) {
          showDialog(
            context: navigator.context,
            builder: (ctx) => ShareCodeDialog(codice: codice),
          );
        }
      },
    );
  }
}

// --- DIALOG: CONDIVISIONE STANZA ---
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
              'Codice di Condivisione',
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
              'Usa questo codice per continuare la conversazione '
              'su un altro dispositivo:',
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

// --- PULSANTE: COLLEGAMENTO A STANZA ---
class RestoreChatTile extends StatelessWidget {
  final Future<bool> Function(String) onRestore;

  const RestoreChatTile({super.key, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      leading: Icon(Icons.settings_backup_restore, color: colorScheme.primary),
      title: const Text('Collegati a una stanza'),
      onTap: () {
        Navigator.pop(context);

        showDialog(
          context: context,
          builder: (ctx) => RestoreChatDialog(onRestore: onRestore),
        );
      },
    );
  }
}

// --- DIALOG: COLLEGAMENTO A STANZA ---
class RestoreChatDialog extends StatefulWidget {
  final Future<bool> Function(String) onRestore;

  const RestoreChatDialog({super.key, required this.onRestore});

  @override
  State<RestoreChatDialog> createState() => _RestoreChatDialogState();
}

class _RestoreChatDialogState extends State<RestoreChatDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

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
              'Codice di collegamento',
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
              enabled: !_isLoading,
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
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _isLoading
              ? null
              : () async {
                  final codice = _codeController.text.trim();
                  if (codice.length != 6) return;

                  setState(() => _isLoading = true);

                  final successo = await widget.onRestore(codice);

                  if (!mounted) return;

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        successo
                            ? 'Collegamento avvenuto con successo!'
                            : 'Codice invalido o scaduto',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
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
              : const Text('Collegati'),
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

// TODO: implementare login
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
