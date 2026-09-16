// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../services/chat_service.dart';
// import '../viewmodels/menu_viewmodel.dart';
//
// // ==========================================
// // SCHERMATA
// // ==========================================
//
// class MenuView extends StatefulWidget {
//   const MenuView({super.key});
//
//   @override
//   State<MenuView> createState() => _MenuViewState();
// }
//
// class _MenuViewState extends State<MenuView> {
//   late MenuViewModel _viewModel;
//
//   @override
//   void initState() {
//     super.initState();
//     _viewModel = MenuViewModel(chatService: context.read<ChatService>());
//
//     _viewModel.onShowMessage = (msg) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis),
//             duration: const Duration(seconds: 2),
//           ),
//         );
//       }
//     };
//
//     _viewModel.onCloseMenu = () {
//       if (mounted && Navigator.canPop(context)) {
//         Navigator.pop(context);
//       }
//     };
//   }
//
//   @override
//   void dispose() {
//     _viewModel.dispose();
//     super.dispose();
//   }
//
//   // --- RENDERING ---
//   @override
//   Widget build(BuildContext context) {
//     final safePadding = MediaQuery.paddingOf(context);
//     final colorScheme = Theme.of(context).colorScheme;
//
//     return ChangeNotifierProvider.value(
//       value: _viewModel,
//       child: Consumer<MenuViewModel>(
//         builder: (context, vm, child) {
//           return Drawer(
//             child: Column(
//               children: [
//                 Container(
//                   width: double.infinity,
//                   padding: EdgeInsets.only(
//                     top: safePadding.top + 24,
//                     bottom: 24,
//                     left: 16,
//                     right: 16,
//                   ),
//                   color: Colors.white,
//                   child: Center(
//                     child: Image.asset(
//                       'assets/magic-logo.png',
//                       height: 40,
//                       fit: BoxFit.contain,
//                       color: colorScheme.primary,
//                     ),
//                   ),
//                 ),
//
//                 Expanded(
//                   child: CustomScrollView(
//                     slivers: [
//                       SliverToBoxAdapter(
//                         child: Padding(
//                           padding: const EdgeInsets.all(16.0),
//                           child: FilledButton.icon(
//                             onPressed: vm.createNewChat,
//                             icon: const Icon(Icons.add),
//                             label: const Text(
//                               'Nuova Chat',
//                               style: TextStyle(fontWeight: FontWeight.bold),
//                             ),
//                             style: FilledButton.styleFrom(
//                               minimumSize: const Size(double.infinity, 48),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//
//                       SliverToBoxAdapter(
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                           child: TextField(
//                             decoration: InputDecoration(
//                               hintText: 'Cerca una chat',
//                               hintStyle: TextStyle(
//                                 color: colorScheme.onSurfaceVariant,
//                                 fontSize: 14,
//                               ),
//                               prefixIcon: Icon(
//                                 Icons.search,
//                                 color: colorScheme.onSurfaceVariant,
//                               ),
//                               filled: true,
//                               fillColor: colorScheme.surfaceContainerHighest
//                                   .withValues(alpha: 0.5),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                                 borderSide: BorderSide.none,
//                               ),
//                               contentPadding: EdgeInsets.zero,
//                             ),
//                             onChanged: vm.searchHistory,
//                           ),
//                         ),
//                       ),
//
//                       const SliverToBoxAdapter(child: SizedBox(height: 8)),
//
//                       if (vm.filteredHistory.isEmpty)
//                         SliverFillRemaining(
//                           hasScrollBody: false,
//                           child: Center(
//                             child: Text(
//                               'Nessuna chat trovata.',
//                               style: TextStyle(
//                                 color: colorScheme.onSurfaceVariant,
//                               ),
//                             ),
//                           ),
//                         )
//                       else
//                         SliverList(
//                           delegate: SliverChildBuilderDelegate((
//                             context,
//                             index,
//                           ) {
//                             final chat = vm.filteredHistory[index];
//                             return ListTile(
//                               title: Text(
//                                 chat.title,
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: const TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                               subtitle: Text(
//                                 '${chat.date.day.toString().padLeft(2, '0')}/'
//                                 '${chat.date.month.toString().padLeft(2, '0')}/'
//                                 '${chat.date.year}',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: colorScheme.onSurfaceVariant,
//                                 ),
//                               ),
//                               trailing: chat.isShared
//                                   ? Icon(
//                                       Icons.people_alt,
//                                       size: 16,
//                                       color: colorScheme.primary.withValues(
//                                         alpha: 0.7,
//                                       ),
//                                     )
//                                   : null,
//                               onTap: () => vm.loadChat(chat.id),
//                             );
//                           }, childCount: vm.filteredHistory.length),
//                         ),
//                     ],
//                   ),
//                 ),
//
//                 Material(
//                   color: Colors.white,
//                   child: Container(
//                     width: double.infinity,
//                     decoration: BoxDecoration(
//                       border: Border(
//                         top: BorderSide(
//                           color: colorScheme.outlineVariant,
//                           width: 1,
//                         ),
//                       ),
//                     ),
//                     padding: EdgeInsets.only(
//                       top: 8,
//                       bottom: safePadding.bottom > 0 ? safePadding.bottom : 8,
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         ShareChatTile(onShare: vm.condividiStanza),
//                         RestoreChatTile(onRestore: vm.collegatiAStanza),
//                         const Padding(
//                           padding: EdgeInsets.symmetric(vertical: 8.0),
//                           child: Divider(height: 1),
//                         ),
//                         ProfileSection(
//                           mockLoggedUser: vm.mockLoggedUser,
//                           onLogin: (user) {
//                             vm.login(user);
//                           },
//                           onLogout: () {
//                             Navigator.pop(context);
//                             vm.logout();
//                           },
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
//
// // ==========================================
// // WIDGET
// // ==========================================
//
// // --- PULSANTE: CONDIVISIONE STANZA ---
// class ShareChatTile extends StatelessWidget {
//   final Future<Map<String, String?>?> Function() onShare;
//
//   const ShareChatTile({super.key, required this.onShare});
//
//   @override
//   Widget build(BuildContext context) {
//     final colorScheme = Theme.of(context).colorScheme;
//
//     return ListTile(
//       dense: true,
//       leading: Icon(Icons.mobile_screen_share, color: colorScheme.primary),
//       title: const Text('Condividi la stanza'),
//       onTap: () async {
//         final navigator = Navigator.of(context, rootNavigator: true);
//         navigator.pop();
//
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (ctx) => const Center(child: CircularProgressIndicator()),
//         );
//
//         final codes = await onShare();
//
//         navigator.pop();
//
//         if (codes != null && navigator.context.mounted) {
//           showDialog(
//             context: navigator.context,
//             builder: (ctx) => ShareCodeDialog(codes: codes),
//           );
//         }
//       },
//     );
//   }
// }
//
// class ShareCodeDialog extends StatefulWidget {
//   final Map<String, String?> codes;
//   const ShareCodeDialog({super.key, required this.codes});
//
//   @override
//   State<ShareCodeDialog> createState() => _ShareCodeDialogState();
// }
//
// class _ShareCodeDialogState extends State<ShareCodeDialog> {
//   String? _copiedCode;
//
//   void _copyToClipboard(String code, String type) async {
//     await Clipboard.setData(ClipboardData(text: code));
//     if (!mounted) return;
//     setState(() => _copiedCode = type);
//     Future.delayed(const Duration(seconds: 2), () {
//       if (mounted) setState(() => _copiedCode = null);
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final colorScheme = Theme.of(context).colorScheme;
//     final isAdmin = widget.codes['role'] == 'admin';
//     final adminCode = widget.codes['admin'];
//     final guestCode = widget.codes['guest'];
//
//     return AlertDialog(
//       titlePadding: EdgeInsets.zero,
//       clipBehavior: Clip.hardEdge,
//       title: Container(
//         color: colorScheme.primaryContainer,
//         padding: const EdgeInsets.all(16),
//         child: Row(
//           children: [
//             Icon(
//               Icons.mobile_screen_share,
//               color: colorScheme.onPrimaryContainer,
//             ),
//             const SizedBox(width: 12),
//             Text(
//               'Codici di Condivisione',
//               style: TextStyle(
//                 color: colorScheme.onPrimaryContainer,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 18,
//               ),
//             ),
//           ],
//         ),
//       ),
//       content: SingleChildScrollView(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Padding(
//               padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
//               child: Text(
//                 isAdmin
//                     ? 'Sei l\'amministratore di questa chat. '
//                           'Scegli quale codice condividere:'
//                     : 'Puoi invitare altri utenti a visualizzare questa chat '
//                           'in sola lettura.',
//               ),
//             ),
//
//             if (isAdmin && adminCode != null) ...[
//               Text(
//                 'ACCESSO COMPLETO (Admin)',
//                 style: TextStyle(
//                   fontSize: 11,
//                   fontWeight: FontWeight.bold,
//                   letterSpacing: 1.2,
//                   color: colorScheme.primary,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               _buildCodeBox(adminCode, 'admin', colorScheme),
//               const SizedBox(height: 24),
//             ],
//
//             if (guestCode != null) ...[
//               Text(
//                 'SOLO LETTURA (Guest)',
//                 style: TextStyle(
//                   fontSize: 11,
//                   fontWeight: FontWeight.bold,
//                   letterSpacing: 1.2,
//                   color: colorScheme.onSurfaceVariant,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               _buildCodeBox(guestCode, 'guest', colorScheme),
//             ],
//           ],
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('Chiudi'),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildCodeBox(String code, String type, ColorScheme colorScheme) {
//     final isCopied = _copiedCode == type;
//
//     return Stack(
//       clipBehavior: Clip.none,
//       children: [
//         Container(
//           width: double.infinity,
//           padding: const EdgeInsets.only(left: 20, right: 8, top: 8, bottom: 8),
//           decoration: BoxDecoration(
//             color: colorScheme.surfaceContainerHighest,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: colorScheme.outlineVariant),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 code,
//                 style: TextStyle(
//                   fontSize: 26,
//                   fontWeight: FontWeight.bold,
//                   letterSpacing: 6,
//                   color: colorScheme.onSurface,
//                 ),
//               ),
//               IconButton(
//                 icon: const Icon(Icons.copy),
//                 color: colorScheme.primary,
//                 tooltip: 'Copia negli appunti',
//                 onPressed: () => _copyToClipboard(code, type),
//               ),
//             ],
//           ),
//         ),
//         if (isCopied)
//           Positioned(
//             top: -12,
//             right: 0,
//             child: IgnorePointer(
//               child: Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 10,
//                   vertical: 6,
//                 ),
//                 decoration: BoxDecoration(
//                   color: Colors.green.shade600,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: const [
//                     BoxShadow(
//                       color: Colors.black26,
//                       blurRadius: 4,
//                       offset: Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: const [
//                     Icon(Icons.check, color: Colors.white, size: 14),
//                     SizedBox(width: 6),
//                     Text(
//                       'Copiato',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 12,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }
// }
//
// // --- PULSANTE: COLLEGAMENTO A STANZA ---
// class RestoreChatTile extends StatelessWidget {
//   final Future<bool> Function(String) onRestore;
//
//   const RestoreChatTile({super.key, required this.onRestore});
//
//   @override
//   Widget build(BuildContext context) {
//     final colorScheme = Theme.of(context).colorScheme;
//
//     return ListTile(
//       dense: true,
//       leading: Icon(Icons.settings_backup_restore, color: colorScheme.primary),
//       title: const Text('Collegati a una stanza'),
//       onTap: () {
//         Navigator.pop(context);
//
//         showDialog(
//           context: context,
//           builder: (ctx) => RestoreChatDialog(onRestore: onRestore),
//         );
//       },
//     );
//   }
// }
//
// // --- DIALOG: COLLEGAMENTO A STANZA ---
// class RestoreChatDialog extends StatefulWidget {
//   final Future<bool> Function(String) onRestore;
//
//   const RestoreChatDialog({super.key, required this.onRestore});
//
//   @override
//   State<RestoreChatDialog> createState() => _RestoreChatDialogState();
// }
//
// class _RestoreChatDialogState extends State<RestoreChatDialog> {
//   final TextEditingController _codeController = TextEditingController();
//   bool _isLoading = false;
//
//   @override
//   void dispose() {
//     _codeController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final colorScheme = Theme.of(context).colorScheme;
//
//     return AlertDialog(
//       titlePadding: EdgeInsets.zero,
//       clipBehavior: Clip.hardEdge,
//       title: Container(
//         color: colorScheme.primaryContainer,
//         padding: const EdgeInsets.all(16),
//         child: Row(
//           children: [
//             Icon(
//               Icons.settings_backup_restore,
//               color: colorScheme.onPrimaryContainer,
//             ),
//
//             const SizedBox(width: 12),
//
//             Text(
//               'Codice di collegamento',
//               style: TextStyle(
//                 color: colorScheme.onPrimaryContainer,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 18,
//               ),
//             ),
//           ],
//         ),
//       ),
//       content: Padding(
//         padding: const EdgeInsets.only(top: 8.0),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Usa un codice per continuare una conversazione.'),
//
//             const SizedBox(height: 16),
//
//             TextField(
//               controller: _codeController,
//               maxLength: 6,
//               textCapitalization: TextCapitalization.characters,
//               enabled: !_isLoading,
//               decoration: InputDecoration(
//                 labelText: 'Codice di 6 caratteri',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 filled: true,
//                 fillColor: colorScheme.surfaceContainerHighest.withValues(
//                   alpha: 0.5,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: _isLoading ? null : () => Navigator.pop(context),
//           child: const Text('Annulla'),
//         ),
//         FilledButton(
//           onPressed: _isLoading
//               ? null
//               : () async {
//                   final codice = _codeController.text.trim();
//                   if (codice.length != 6) return;
//
//                   setState(() => _isLoading = true);
//
//                   final successo = await widget.onRestore(codice);
//
//                   if (!mounted) return;
//
//                   Navigator.pop(context);
//
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(
//                         successo
//                             ? 'Collegamento avvenuto con successo'
//                             : 'Codice invalido o scaduto',
//                       ),
//                       duration: const Duration(seconds: 2),
//                     ),
//                   );
//                 },
//           child: _isLoading
//               ? const SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     color: Colors.white,
//                   ),
//                 )
//               : const Text('Collegati'),
//         ),
//       ],
//     );
//   }
// }
//
// // --- SEZIONE PROFILO ---
// class ProfileSection extends StatelessWidget {
//   final String? mockLoggedUser;
//   final ValueChanged<String> onLogin;
//   final VoidCallback onLogout;
//
//   const ProfileSection({
//     super.key,
//     required this.mockLoggedUser,
//     required this.onLogin,
//     required this.onLogout,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final colorScheme = Theme.of(context).colorScheme;
//
//     if (mockLoggedUser != null) {
//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Flexible(
//               child: Chip(
//                 avatar: Icon(
//                   Icons.person,
//                   color: colorScheme.onPrimaryContainer,
//                 ),
//                 label: Text(
//                   mockLoggedUser!,
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     color: colorScheme.onPrimaryContainer,
//                   ),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 backgroundColor: colorScheme.primaryContainer,
//                 side: BorderSide.none,
//               ),
//             ),
//             IconButton(
//               icon: const Icon(Icons.logout),
//               color: colorScheme.error,
//               tooltip: 'Esci',
//               onPressed: onLogout,
//             ),
//           ],
//         ),
//       );
//     }
//
//     return ListTile(
//       dense: true,
//       leading: Icon(Icons.login, color: colorScheme.primary),
//       title: const Text('Accedi'),
//       onTap: () {},
//     );
//   }
// }

// TODO: implementare login, cronologia, nuova chat

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

    _viewModel.onCloseMenu = () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
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
    final colorScheme = Theme.of(context).colorScheme;

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final compactMode = isLandscape && !isTablet;

    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<MenuViewModel>(
        builder: (context, vm, child) {
          return Drawer(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: safePadding.top + (compactMode ? 12 : 24),
                    bottom: compactMode ? 12 : 24,
                    left: 16,
                    right: 16,
                  ),
                  color: Colors.white,
                  child: Center(
                    child: Image.asset(
                      'assets/magic-logo.png',
                      height: compactMode ? 24 : 40,
                      fit: BoxFit.contain,
                      color: colorScheme.primary,
                    ),
                  ),
                ),

                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(compactMode ? 12.0 : 16.0),
                          child: FilledButton.icon(
                            onPressed: vm.createNewChat,
                            icon: Icon(Icons.add, size: compactMode ? 18 : 24),
                            label: Text(
                              'Nuova Chat',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: compactMode ? 13 : 14,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: Size(
                                double.infinity,
                                compactMode ? 36 : 48,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            style: TextStyle(fontSize: compactMode ? 13 : 14),
                            decoration: InputDecoration(
                              hintText: 'Cerca una chat',
                              hintStyle: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: compactMode ? 13 : 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: colorScheme.onSurfaceVariant,
                                size: compactMode ? 20 : 24,
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: vm.searchHistory,
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: SizedBox(height: compactMode ? 4 : 8),
                      ),

                      if (vm.filteredHistory.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'Nessuna chat trovata.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: compactMode ? 13 : 14,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final chat = vm.filteredHistory[index];
                            return ListTile(
                              dense: compactMode,
                              title: Text(
                                chat.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: compactMode ? 13 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                '${chat.date.day.toString().padLeft(2, '0')}/'
                                '${chat.date.month.toString().padLeft(2, '0')}/'
                                '${chat.date.year}',
                                style: TextStyle(
                                  fontSize: compactMode ? 11 : 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: chat.isShared
                                  ? Icon(
                                      Icons.people_alt,
                                      size: compactMode ? 14 : 16,
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.7,
                                      ),
                                    )
                                  : null,
                              onTap: () => vm.loadChat(chat.id),
                            );
                          }, childCount: vm.filteredHistory.length),
                        ),
                    ],
                  ),
                ),

                Material(
                  color: Colors.white,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.only(
                      top: compactMode ? 0 : 8,
                      bottom: safePadding.bottom > 0
                          ? safePadding.bottom
                          : (compactMode ? 4 : 8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShareChatTile(
                          onShare: vm.condividiStanza,
                          compactMode: compactMode,
                        ),
                        RestoreChatTile(
                          onRestore: vm.collegatiAStanza,
                          compactMode: compactMode,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: compactMode ? 0.0 : 8.0,
                          ),
                          child: const Divider(height: 1),
                        ),
                        ProfileSection(
                          mockLoggedUser: vm.mockLoggedUser,
                          compactMode: compactMode,
                          onLogin: (user) {
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
  final Future<Map<String, String?>?> Function() onShare;
  final bool compactMode;

  const ShareChatTile({
    super.key,
    required this.onShare,
    required this.compactMode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: compactMode,
      visualDensity: compactMode
          ? const VisualDensity(horizontal: 0, vertical: -4)
          : null,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compactMode ? 0 : 4,
      ),
      minVerticalPadding: compactMode ? 0 : 4,
      leading: Icon(
        Icons.mobile_screen_share,
        color: colorScheme.primary,
        size: compactMode ? 20 : 24,
      ),
      title: Text(
        'Condividi la stanza',
        style: TextStyle(fontSize: compactMode ? 13 : 14),
      ),
      onTap: () async {
        final navigator = Navigator.of(context, rootNavigator: true);
        navigator.pop();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );

        final codes = await onShare();

        navigator.pop();

        if (codes != null && navigator.context.mounted) {
          showDialog(
            context: navigator.context,
            builder: (ctx) => ShareCodeDialog(codes: codes),
          );
        }
      },
    );
  }
}

class ShareCodeDialog extends StatefulWidget {
  final Map<String, String?> codes;
  const ShareCodeDialog({super.key, required this.codes});

  @override
  State<ShareCodeDialog> createState() => _ShareCodeDialogState();
}

class _ShareCodeDialogState extends State<ShareCodeDialog> {
  String? _copiedCode;

  void _copyToClipboard(String code, String type) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copiedCode = type);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedCode = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAdmin = widget.codes['role'] == 'admin';
    final adminCode = widget.codes['admin'];
    final guestCode = widget.codes['guest'];

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final compactMode = isLandscape && !isTablet;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      title: Container(
        color: colorScheme.primaryContainer,
        padding: EdgeInsets.all(compactMode ? 12 : 16),
        child: Row(
          children: [
            Icon(
              Icons.mobile_screen_share,
              color: colorScheme.onPrimaryContainer,
              size: compactMode ? 20 : 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Codici di Condivisione',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: compactMode ? 16 : 18,
              ),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: 8.0,
                bottom: compactMode ? 12.0 : 24.0,
              ),
              child: Text(
                isAdmin
                    ? 'Sei l\'amministratore di questa chat. '
                          'Scegli quale codice condividere:'
                    : 'Puoi invitare altri utenti a visualizzare questa chat '
                          'in sola lettura.',
                style: TextStyle(fontSize: compactMode ? 13 : 14),
              ),
            ),

            if (isAdmin && adminCode != null) ...[
              Text(
                'ACCESSO COMPLETO (Admin)',
                style: TextStyle(
                  fontSize: compactMode ? 10 : 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: colorScheme.primary,
                ),
              ),
              SizedBox(height: compactMode ? 4 : 8),
              _buildCodeBox(adminCode, 'admin', colorScheme, compactMode),
              SizedBox(height: compactMode ? 12 : 24),
            ],

            if (guestCode != null) ...[
              Text(
                'SOLO LETTURA (Guest)',
                style: TextStyle(
                  fontSize: compactMode ? 10 : 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: compactMode ? 4 : 8),
              _buildCodeBox(guestCode, 'guest', colorScheme, compactMode),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi'),
        ),
      ],
    );
  }

  Widget _buildCodeBox(
    String code,
    String type,
    ColorScheme colorScheme,
    bool compactMode,
  ) {
    final isCopied = _copiedCode == type;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            left: 20,
            right: 8,
            top: compactMode ? 4 : 8,
            bottom: compactMode ? 4 : 8,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                code,
                style: TextStyle(
                  fontSize: compactMode ? 20 : 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: colorScheme.onSurface,
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy, size: compactMode ? 20 : 24),
                color: colorScheme.primary,
                tooltip: 'Copia negli appunti',
                onPressed: () => _copyToClipboard(code, type),
              ),
            ],
          ),
        ),
        if (isCopied)
          Positioned(
            top: -12,
            right: 0,
            child: IgnorePointer(
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
      ],
    );
  }
}

// --- PULSANTE: COLLEGAMENTO A STANZA ---
class RestoreChatTile extends StatelessWidget {
  final Future<bool> Function(String) onRestore;
  final bool compactMode;

  const RestoreChatTile({
    super.key,
    required this.onRestore,
    required this.compactMode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: compactMode,
      visualDensity: compactMode
          ? const VisualDensity(horizontal: 0, vertical: -4)
          : null,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compactMode ? 0 : 4,
      ),
      minVerticalPadding: compactMode ? 0 : 4,
      leading: Icon(
        Icons.settings_backup_restore,
        color: colorScheme.primary,
        size: compactMode ? 20 : 24,
      ),
      title: Text(
        'Collegati a una stanza',
        style: TextStyle(fontSize: compactMode ? 13 : 14),
      ),
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
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final compactMode = isLandscape && !isTablet;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      title: Container(
        color: colorScheme.primaryContainer,
        padding: EdgeInsets.all(compactMode ? 12 : 16),
        child: Row(
          children: [
            Icon(
              Icons.settings_backup_restore,
              color: colorScheme.onPrimaryContainer,
              size: compactMode ? 20 : 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Codice di collegamento',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: compactMode ? 16 : 18,
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
            Text(
              'Usa un codice per continuare una conversazione.',
              style: TextStyle(fontSize: compactMode ? 13 : 14),
            ),

            SizedBox(height: compactMode ? 12 : 16),

            TextField(
              controller: _codeController,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              enabled: !_isLoading,
              style: TextStyle(fontSize: compactMode ? 13 : 14),
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
                            ? 'Collegamento avvenuto con successo'
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
  final bool compactMode;

  const ProfileSection({
    super.key,
    required this.mockLoggedUser,
    required this.onLogin,
    required this.onLogout,
    required this.compactMode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (mockLoggedUser != null) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: compactMode ? 2 : 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Chip(
                visualDensity: compactMode ? VisualDensity.compact : null,
                avatar: Icon(
                  Icons.person,
                  color: colorScheme.onPrimaryContainer,
                  size: compactMode ? 18 : 24,
                ),
                label: Text(
                  mockLoggedUser!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                    fontSize: compactMode ? 12 : 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: colorScheme.primaryContainer,
                side: BorderSide.none,
              ),
            ),
            IconButton(
              icon: Icon(Icons.logout, size: compactMode ? 20 : 24),
              color: colorScheme.error,
              tooltip: 'Esci',
              onPressed: onLogout,
            ),
          ],
        ),
      );
    }

    return ListTile(
      dense: compactMode,
      visualDensity: compactMode
          ? const VisualDensity(horizontal: 0, vertical: -4)
          : null,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compactMode ? 0 : 4,
      ),
      minVerticalPadding: compactMode ? 0 : 4,
      leading: Icon(
        Icons.login,
        color: colorScheme.primary,
        size: compactMode ? 20 : 24,
      ),
      title: Text('Accedi', style: TextStyle(fontSize: compactMode ? 13 : 14)),
      onTap: () {},
    );
  }
}
