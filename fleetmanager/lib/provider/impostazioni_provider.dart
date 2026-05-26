import 'package:flutter/material.dart';
import 'package:fleetmanager/services/impostazioni_service.dart';

class ImpostazioniProvider with ChangeNotifier {
  final ImpostazioniService _service;

  bool fotoScontrinoObbligatoria = true;
  bool fotoDanniObbligatoria = false;
  bool fotoPedaggiObbligatoria = false;
  bool checkupObbligatorio = true;
  bool approvazioneRichiesta = true;
  bool moduloPedaggiAbilitato = true;
  bool _caricato = false;
  Future<void>? _caricamento;

  ImpostazioniProvider({ImpostazioniService? service})
      : _service = service ?? ImpostazioniService();

  bool get caricato => _caricato;

  Future<void> carica() {
    _caricamento ??= _caricaInterno();
    return _caricamento!;
  }

  Future<void> ensureLoaded() => carica();

  Future<void> _caricaInterno() async {
    fotoScontrinoObbligatoria = await _service.getFotoScontrinoObbligatoria();
    fotoDanniObbligatoria = await _service.getFotoDanniObbligatoria();
    fotoPedaggiObbligatoria = await _service.getFotoPedaggiObbligatoria();
    checkupObbligatorio = await _service.getCheckupObbligatorio();
    approvazioneRichiesta = await _service.getApprovazioneRichiesta();
    moduloPedaggiAbilitato = await _service.getModuloPedaggiAbilitato();
    _caricato = true;
    notifyListeners();
  }

  Future<void> setFotoScontrinoObbligatoria(bool v) async {
    fotoScontrinoObbligatoria = v;
    await _service.setFotoScontrinoObbligatoria(v);
    notifyListeners();
  }

  Future<void> setFotoDanniObbligatoria(bool v) async {
    fotoDanniObbligatoria = v;
    await _service.setFotoDanniObbligatoria(v);
    notifyListeners();
  }

  Future<void> setFotoPedaggiObbligatoria(bool v) async {
    fotoPedaggiObbligatoria = v;
    await _service.setFotoPedaggiObbligatoria(v);
    notifyListeners();
  }

  Future<void> setCheckupObbligatorio(bool v) async {
    checkupObbligatorio = v;
    await _service.setCheckupObbligatorio(v);
    notifyListeners();
  }

  Future<void> setApprovazioneRichiesta(bool v) async {
    approvazioneRichiesta = v;
    await _service.setApprovazioneRichiesta(v);
    notifyListeners();
  }

  Future<void> setModuloPedaggiAbilitato(bool v) async {
    moduloPedaggiAbilitato = v;
    await _service.setModuloPedaggiAbilitato(v);
    notifyListeners();
  }
}
