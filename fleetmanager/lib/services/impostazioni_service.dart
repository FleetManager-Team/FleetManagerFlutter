import 'package:shared_preferences/shared_preferences.dart';

class ImpostazioniService {
  static const _fotoScontrinoKey = 'foto_scontrino_obbligatoria';
  static const _fotoDanniKey = 'foto_danni_obbligatoria';
  static const _fotoPedaggiKey = 'foto_pedaggi_obbligatoria';
  static const _checkupObbligatorioKey = 'checkup_iniziale_obbligatorio';
  static const _approvazioneRichiestaKey = 'approvazione_prenotazioni_richiesta';
  static const _moduloPedaggiKey = 'modulo_pedaggi_abilitato';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> getFotoScontrinoObbligatoria() async =>
      (await _prefs).getBool(_fotoScontrinoKey) ?? true;

  Future<bool> getFotoDanniObbligatoria() async =>
      (await _prefs).getBool(_fotoDanniKey) ?? false;

  Future<bool> getFotoPedaggiObbligatoria() async =>
      (await _prefs).getBool(_fotoPedaggiKey) ?? false;

  Future<bool> getCheckupObbligatorio() async =>
      (await _prefs).getBool(_checkupObbligatorioKey) ?? true;

  Future<bool> getApprovazioneRichiesta() async =>
      (await _prefs).getBool(_approvazioneRichiestaKey) ?? true;

  Future<bool> getModuloPedaggiAbilitato() async =>
      (await _prefs).getBool(_moduloPedaggiKey) ?? true;

  Future<void> setFotoScontrinoObbligatoria(bool v) async =>
      (await _prefs).setBool(_fotoScontrinoKey, v);

  Future<void> setFotoDanniObbligatoria(bool v) async =>
      (await _prefs).setBool(_fotoDanniKey, v);

  Future<void> setFotoPedaggiObbligatoria(bool v) async =>
      (await _prefs).setBool(_fotoPedaggiKey, v);

  Future<void> setCheckupObbligatorio(bool v) async =>
      (await _prefs).setBool(_checkupObbligatorioKey, v);

  Future<void> setApprovazioneRichiesta(bool v) async =>
      (await _prefs).setBool(_approvazioneRichiestaKey, v);

  Future<void> setModuloPedaggiAbilitato(bool v) async =>
      (await _prefs).setBool(_moduloPedaggiKey, v);
}
