import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';

// ==========================================
// SCHERMATA
// ==========================================

class MenuWidget extends StatefulWidget {
  const MenuWidget({super.key});

  @override
  State<MenuWidget> createState() => _MenuWidgetState();
}

class _MenuWidgetState extends State<MenuWidget> {
  // TODO; rimuovere quando disponibile login
  static String? _mockLoggedUser;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // --- RENDERING ---
  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);

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

          Container(
            width: double.infinity,
            color: Colors.white,
            padding: EdgeInsets.only(top: 8, bottom: safePadding.bottom + 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const ShareChatTile(),

                const RestoreChatTile(),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1),
                ),

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
              ],
            ),
          ),
        ],
      ),
    );
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
// TODO: Sostituire con login di AuthService
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
