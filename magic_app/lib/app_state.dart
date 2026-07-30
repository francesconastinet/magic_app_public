import 'package:flutter/material.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  int _opereRiconosciute = 0;
  String? _ultimaOpera;
  BookModel? _operaSelezionata;

  int get opereRiconosciute => _opereRiconosciute;
  String? get ultimaOpera => _ultimaOpera;
  BookModel? get operaSelezionata => _operaSelezionata;

  void riconosciOpera(String nomeOpera) {
    _ultimaOpera = nomeOpera;
    _opereRiconosciute++;
    notifyListeners();
  }

  void selezionaOpera(BookModel opera) {
    _operaSelezionata = opera;
    notifyListeners();
  }
}
