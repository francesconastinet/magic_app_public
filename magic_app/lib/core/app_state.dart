import 'package:flutter/material.dart';
import '../data/models.dart';

class AppState extends ChangeNotifier {
  int _opereRiconosciute = 0;
  String? _ultimaOpera;
  BookModel? _operaSelezionata;
  bool _isSyncing = false;
  // collection_id scelto nel catalogo (null = nessuna collezione, il
  // chatbot risponde su tutto). Lo imposta il catalogo quando si preme Applica.
  String? _collezioneChat;

  int get opereRiconosciute => _opereRiconosciute;
  String? get ultimaOpera => _ultimaOpera;
  BookModel? get operaSelezionata => _operaSelezionata;
  bool get isSyncing => _isSyncing;
  String? get collezioneChat => _collezioneChat;

  void riconosciOpera(String nomeOpera) {
    _ultimaOpera = nomeOpera;
    _opereRiconosciute++;
    notifyListeners();
  }

  void selezionaOpera(BookModel opera) {
    _operaSelezionata = opera;
    notifyListeners();
  }

  // usato da "Nuova chat": azzera l'ultima opera scansionata, cosi' la Home
  // non la riseleziona da sola al prossimo cambio di stato.
  // Azzera anche la collezione scelta nel catalogo, cosi' la nuova chat
  // riparte senza collection_id.
  void azzeraOperaSelezionata() {
    _operaSelezionata = null;
    _collezioneChat = null;
    notifyListeners();
  }

  void setSyncing(bool value) {
    _isSyncing = value;
    notifyListeners();
  }

  // salva il collection_id scelto nel catalogo (null per toglierlo)
  void impostaCollezioneChat(String? collectionId) {
    final valore = (collectionId != null && collectionId.trim().isNotEmpty)
        ? collectionId.trim()
        : null;
    if (_collezioneChat == valore) return;
    _collezioneChat = valore;
    notifyListeners();
  }
}