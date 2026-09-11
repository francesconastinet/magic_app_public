import 'package:flutter/foundation.dart';
import '../core/app_state.dart';
import '../data/models.dart';

class DetailViewModel extends ChangeNotifier {
  // --- DIPENDENZE ---
  final AppState _appState;
  final BookModel book;

  // --- STATO ---
  MediaItem? audioInEsecuzione;
  bool audioMinimizzato = false;

  DetailViewModel({required this._appState, required this.book});

  // --- LOGICA ---

  void playAudio(MediaItem item) {
    audioInEsecuzione = item;
    audioMinimizzato = false;
    notifyListeners();
  }

  void minimizeAudio() {
    audioMinimizzato = true;
    notifyListeners();
  }

  void closeAudio() {
    audioInEsecuzione = null;
    notifyListeners();
  }

  void chiediAllAssistente() {
    _appState.selezionaOpera(book);
  }
}
