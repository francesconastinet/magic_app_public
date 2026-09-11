// TODO: implementare login e cronologia chat

import 'package:flutter/foundation.dart';
import '../services/chat_service.dart';

// --- MOCK CRONOLOGIA ---
class ChatHistoryItem {
  final String id;
  final String title;
  final DateTime date;

  ChatHistoryItem({required this.id, required this.title, required this.date});
}

class MenuViewModel extends ChangeNotifier {
  // --- DIPENDENZE ---
  final ChatService _chatService;

  // --- STATO ---
  String _searchQuery = '';
  static String? _globalMockUser;
  final List<ChatHistoryItem> _fullHistory = [
    ChatHistoryItem(
      id: '1',
      title: 'Divina Commedia e Virgilio',
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
    ChatHistoryItem(
      id: '2',
      title: 'Informazioni sui Promessi Sposi',
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
    ChatHistoryItem(
      id: '3',
      title: 'Manoscritti medievali',
      date: DateTime.now().subtract(const Duration(days: 5)),
    ),
    ChatHistoryItem(
      id: '4',
      title: 'Codici miniati napoletani',
      date: DateTime.now().subtract(const Duration(days: 10)),
    ),
    ChatHistoryItem(
      id: '5',
      title: 'La biblioteca dei Girolamini',
      date: DateTime.now().subtract(const Duration(days: 15)),
    ),
    ChatHistoryItem(
      id: '6',
      title: 'Struttura dell\'Inferno',
      date: DateTime.now().subtract(const Duration(days: 6)),
    ),
    ChatHistoryItem(
      id: '7',
      title: 'Biografia di Dante',
      date: DateTime.now().subtract(const Duration(days: 12)),
    ),
    ChatHistoryItem(
      id: '8',
      title: 'Biografia di Manzoni',
      date: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  // --- EVENTI UI ---
  void Function(String)? onShowMessage;
  void Function()? onCloseMenu;

  // --- GETTER ---
  String? get mockLoggedUser => _globalMockUser;
  List<ChatHistoryItem> get filteredHistory {
    if (_searchQuery.trim().isEmpty) return _fullHistory;
    return _fullHistory
        .where(
          (chat) =>
              chat.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  MenuViewModel({required this._chatService});

  // --- LOGICA ---

  void login(String username) {
    _globalMockUser = username;
    notifyListeners();
    onShowMessage?.call('Benvenuto, $username!');
  }

  void logout() {
    _globalMockUser = null;
    notifyListeners();
    onShowMessage?.call('Logout effettuato');
  }

  Future<String?> condividiStanza() async {
    return await _chatService.recuperaCodiceStanza();
  }

  Future<bool> collegatiAStanza(String codice) async {
    return await _chatService.leggiStanza(codice);
  }

  void searchHistory(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void createNewChat() {
    _chatService.resetContextSession();
    onCloseMenu?.call();
  }

  void loadChat(String id) {
    onCloseMenu?.call();
  }
}
