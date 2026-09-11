import 'package:flutter/material.dart';
import '../data/models.dart';

class AppState extends ChangeNotifier {
  int _opereRiconosciute = 0;
  String? _ultimaOpera;
  BookModel? _operaSelezionata;
  bool _isSyncing = false;

  int get opereRiconosciute => _opereRiconosciute;
  String? get ultimaOpera => _ultimaOpera;
  BookModel? get operaSelezionata => _operaSelezionata;
  bool get isSyncing => _isSyncing;

  void riconosciOpera(String nomeOpera) {
    _ultimaOpera = nomeOpera;
    _opereRiconosciute++;
    notifyListeners();
  }

  void selezionaOpera(BookModel opera) {
    _operaSelezionata = opera;
    notifyListeners();
  }

  void setSyncing(bool value) {
    _isSyncing = value;
    notifyListeners();
  }
}
