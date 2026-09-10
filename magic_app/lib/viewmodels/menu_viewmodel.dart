import 'package:flutter/foundation.dart';
import '../services/chat_service.dart';

class MenuViewModel extends ChangeNotifier {
  // --- DIPENDENZE ---
  final ChatService _chatService;

  // --- STATO ---
  // TODO: implementare login
  String? mockLoggedUser;

  // --- EVENTI UI ---
  void Function(String)? onShowMessage;

  MenuViewModel({required this._chatService});

  // --- LOGICA ---

  void login(String username) {
    mockLoggedUser = username;
    notifyListeners();
    onShowMessage?.call('Benvenuto, $username!');
  }

  void logout() {
    mockLoggedUser = null;
    notifyListeners();
    onShowMessage?.call('Logout effettuato');
  }

  Future<String?> condividiStanza() async {
    return await _chatService.recuperaCodiceStanza();
  }

  Future<bool> collegatiAStanza(String codice) async {
    return await _chatService.leggiStanza(codice);
  }
}
