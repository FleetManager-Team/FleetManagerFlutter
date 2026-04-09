import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;

import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/services/restituzione_service.dart';

class RestituzioneVeicoloScreen extends StatefulWidget {
  final Prenotazione prenotazione;
  final bool isEmergenza;

  const RestituzioneVeicoloScreen({
    super.key,
    required this.prenotazione,
    this.isEmergenza = false,
  });

  @override
  State<RestituzioneVeicoloScreen> createState() =>
      _RestituzioneVeicoloScreenState();
}

class _RestituzioneVeicoloScreenState extends State<RestituzioneVeicoloScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  dynamic _veicolo;

  // Controller Originali
  late TextEditingController _kmController;
  final _litriController = TextEditingController();
  final _euroController = TextEditingController();
  final _euroPedaggiController = TextEditingController();
  final _descrizioneDanniController = TextEditingController();
  final _posizioneController = TextEditingController();

  // Stato UI Originale
  double _livelloCarburante = 16.0;
  bool _rifornimentoEffettuato = false;
  bool _haPedaggi = false;
  bool _danniPresenti = false;
  bool _isLocating = false;
  bool _eraGiaEmergenza = false;

  // Foto Originali
  XFile? _fotoScontrino, _fotoPedaggio, _fotoDanni;
  String? _urlFotoScontrinoEsistente,
      _urlFotoPedaggioEsistente,
      _urlFotoDanniEsistente;

  @override
  void initState() {
    super.initState();
    _kmController = TextEditingController(text: "Caricamento...");
    _inizializzaDati();
  }

  Future<void> _inizializzaDati() async {
    await _recuperaDatiVeicolo();
    await _caricaDatiRestituzioneEsistente();

    if (mounted) {
      setState(() {
        // --- LOGICA KM RICHIESTA ---
        // Se non abbiamo caricato dati dal DB (kmController ancora in caricamento o vuoto)
        // carichiamo i KM attuali del veicolo nel box.
        if ((_kmController.text == "Caricamento..." ||
                _kmController.text.isEmpty) &&
            _veicolo != null) {
          _kmController.text = _veicolo!.km.toString();
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _recuperaDatiVeicolo() async {
    try {
      final fleetProvider = Provider.of<FleetProvider>(context, listen: false);
      _veicolo =
          await fleetProvider.getVeicoloDallaTarga(widget.prenotazione.targa);
    } catch (e) {
      debugPrint("Errore: $e");
    }
  }

  Future<void> _caricaDatiRestituzioneEsistente() async {
    try {
      final data = await Supabase.instance.client
          .from('restituzioni')
          .select()
          .eq('id_prenotazione', widget.prenotazione.idPrenotazione)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _eraGiaEmergenza = data['is_emergenza'] ?? false;

          if (data['km_finali'] != 0) {
            _kmController.text = data['km_finali'].toString();
          }

          _livelloCarburante = (data['livello_carburante'] as num).toDouble();
          _rifornimentoEffettuato = data['rifornimento_effettuato'] ?? false;
          if (_rifornimentoEffettuato) {
            _litriController.text = data['litri_carburante']?.toString() ?? "";
            _euroController.text = data['importo_euro']?.toString() ?? "";
            _urlFotoScontrinoEsistente = data['url_scontrino'];
          }
          _haPedaggi = data['ha_pedaggi'] ?? false;
          if (_haPedaggi) {
            _euroPedaggiController.text =
                data['importo_pedaggi']?.toString() ?? "";
            _urlFotoPedaggioEsistente = data['url_foto_pedaggio'];
          }
          _danniPresenti = data['danni_presenti'] ?? false;
          if (_danniPresenti) {
            _descrizioneDanniController.text = data['descrizione_danni'] ?? "";
            _urlFotoDanniEsistente = data['url_foto_danni'];
          }
          _posizioneController.text = data['posizione_emergenza'] ?? "";
        });
      }
    } catch (e) {
      debugPrint("Errore recupero dati: $e");
    }
  }

  Future<void> _prendiPosizioneGps() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));
      setState(() {
        _posizioneController.text =
            "${position.latitude}, ${position.longitude}";
        _isLocating = false;
      });
    } catch (e) {
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Imprevisto GPS: $e"),
            backgroundColor: Colors.orange),
      );
    }
  }

  @override
  void dispose() {
    _kmController.dispose();
    _litriController.dispose();
    _euroController.dispose();
    _descrizioneDanniController.dispose();
    _euroPedaggiController.dispose();
    _posizioneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color themeColor =
        widget.isEmergenza ? Colors.red[700]! : const Color(0xFF388E3C);
    final String title =
        widget.isEmergenza ? "Segnalazione Emergenza" : "Restituzione Veicolo";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVehicleHeader(themeColor),
                    const SizedBox(height: 25),
                    if (widget.isEmergenza) ..._buildEmergencyFields(),
                    if (!widget.isEmergenza) ..._buildStandardReturnFields(),
                    const SizedBox(height: 40),
                    _buildSubmitButton(themeColor),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _buildEmergencyFields() {
    return [
      const Text("Localizzazione e Guasto",
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
      const SizedBox(height: 15),
      _buildPosizioneField(),
      const SizedBox(height: 15),
      _buildTextField(
        _descrizioneDanniController,
        "Descrizione imprevisto/guasto",
        Icons.error_outline,
        maxLines: 3,
      ),
    ];
  }

  List<Widget> _buildStandardReturnFields() {
    return [
      const Text("Dati di rientro",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 15),
      _buildKmField(),
      const SizedBox(height: 25),
      const Text("Livello Carburante",
          style: TextStyle(fontWeight: FontWeight.bold)),
      _buildFuelSelector(),
      _buildSwitch(
          "Hai fatto rifornimento?",
          _rifornimentoEffettuato,
          (v) => setState(() => _rifornimentoEffettuato = v),
          const Color(0xFF388E3C)),
      if (_rifornimentoEffettuato) ...[
        Row(
          children: [
            Expanded(
                child: _buildTextField(
                    _litriController, "Litri", Icons.local_gas_station)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildTextField(
                    _euroController, "Importo Euro", Icons.euro)),
          ],
        ),
        _buildPhotoSelector("Foto Scontrino", _fotoScontrino, "scontrino"),
      ],
      const Divider(height: 40),
      _buildSwitch("Hai pagato pedaggi o parcheggi?", _haPedaggi,
          (v) => setState(() => _haPedaggi = v), Colors.blueAccent),
      if (_haPedaggi) ...[
        _buildTextField(_euroPedaggiController, "Importo Pedaggi (Euro)",
            Icons.payments_outlined),
        _buildPhotoSelector("Foto Ricevuta Pedaggio", _fotoPedaggio, "pedaggi"),
      ],
      const Divider(height: 40),
      _buildSwitch("Sono presenti nuovi danni?", _danniPresenti,
          (v) => setState(() => _danniPresenti = v), Colors.red),
      if (_danniPresenti) ...[
        _buildTextField(
            _descrizioneDanniController, "Descrizione danni", Icons.edit_note,
            maxLines: 3),
        _buildPhotoSelector("Foto Danno", _fotoDanni, "danni"),
      ],
    ];
  }

  Widget _buildVehicleHeader(Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!)),
      child: Row(
        children: [
          Icon(Icons.directions_car, color: color, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _veicolo != null
                        ? "${_veicolo!.marca} ${_veicolo!.modello}"
                        : "Veicolo...",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Targa: ${widget.prenotazione.targa}",
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKmField() {
    return TextFormField(
      controller: _kmController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: "Chilometri attuali",
        prefixIcon: const Icon(Icons.speed),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return "Inserisci i KM";
        final n = int.tryParse(v);
        if (n == null) return "Numero non valido";
        if (_veicolo != null && n < _veicolo!.km)
          return "KM inferiori ai precedenti (${_veicolo!.km})";
        return null;
      },
    );
  }

  Widget _buildPosizioneField() {
    return TextFormField(
      controller: _posizioneController,
      decoration: InputDecoration(
        labelText: "Posizione veicolo",
        hintText: "Indirizzo o coordinate GPS",
        prefixIcon: const Icon(Icons.location_on),
        suffixIcon: _isLocating
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
                icon: const Icon(Icons.gps_fixed, color: Colors.blue),
                onPressed: _prendiPosizioneGps),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildFuelSelector() {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
              trackHeight: 10.0,
              activeTrackColor: const Color(0xFF388E3C),
              thumbColor: const Color(0xFF388E3C)),
          child: Slider(
            value: _livelloCarburante,
            min: 0,
            max: 16,
            divisions: 16,
            label: _getFuelLabel(_livelloCarburante),
            onChanged: (val) => setState(() => _livelloCarburante = val),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
                9,
                (i) => Text(i == 0 ? "V" : (i == 8 ? "P" : "$i/8"),
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold))),
          ),
        ),
      ],
    );
  }

  String _getFuelLabel(double value) {
    int s = value.round();
    if (s <= 0) return "Vuoto";
    if (s >= 16) return "Pieno";
    return "${(s / 2).toStringAsFixed(1)}/8";
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: maxLines > 1
            ? TextInputType.multiline
            : const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _buildSwitch(
      String title, bool value, Function(bool) onChanged, Color activeColor) {
    return SwitchListTile(
        title: Text(title),
        value: value,
        activeColor: activeColor,
        onChanged: onChanged);
  }

  Widget _buildPhotoSelector(String label, XFile? file, String tipo) {
    String? urlEsistente = (tipo == "danni")
        ? _urlFotoDanniEsistente
        : (tipo == "pedaggi"
            ? _urlFotoPedaggioEsistente
            : _urlFotoScontrinoEsistente);
    bool hasPhoto = file != null || urlEsistente != null;
    return ListTile(
      leading: Icon(hasPhoto ? Icons.check_circle : Icons.add_a_photo,
          color: hasPhoto ? Colors.green : Colors.grey),
      title: Text(label),
      trailing: hasPhoto
          ? _buildPreview(file, urlEsistente)
          : const Icon(Icons.chevron_right),
      onTap: () => _prendiFoto(context, tipo),
    );
  }

  Widget _buildPreview(XFile? file, String? url) {
    if (file != null) {
      return kIsWeb
          ? Image.network(file.path, width: 40, height: 40, fit: BoxFit.cover)
          : Image.file(File(file.path),
              width: 40, height: 40, fit: BoxFit.cover);
    }
    return Image.network(url!, width: 40, height: 40, fit: BoxFit.cover);
  }

  Future<void> _prendiFoto(BuildContext context, String tipo) async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        if (tipo == "danni")
          _fotoDanni = image;
        else if (tipo == "pedaggi")
          _fotoPedaggio = image;
        else
          _fotoScontrino = image;
      });
    }
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Controllo foto obbligatoria solo se non è emergenza
    if (!widget.isEmergenza &&
        _rifornimentoEffettuato &&
        _fotoScontrino == null &&
        _urlFotoScontrinoEsistente == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Inserisci la foto dello scontrino."),
          backgroundColor: Colors.orange));
      return;
    }

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<FleetProvider>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      // LOGICA RICHIESTA: Se nasce emergenza, deve rimanere emergenza a vita (true).
      final bool persistenceEmergenza = _eraGiaEmergenza || widget.isEmergenza;
      // Se siamo nel form SOS i chilometri inviati saranno 0 (indica emergenza attiva)
      // Se l'utente li scrive (restituzione standard), carichiamo quelli.
      final int kmDaInviare =
          widget.isEmergenza ? 0 : (int.tryParse(_kmController.text) ?? 0);

      await RestituzioneService().completaRestituzione(
        idPrenotazione: widget.prenotazione.idPrenotazione,
        targa: widget.prenotazione.targa,
        kmFinali: kmDaInviare,
        livelloCarburante: _livelloCarburante,
        rifornimento: _rifornimentoEffettuato,
        haDanni: _danniPresenti || persistenceEmergenza,
        haPedaggi: _haPedaggi,
        isEmergenza: persistenceEmergenza,
        noteEmergenza: _descrizioneDanniController.text,
        posizioneEmergenza: _posizioneController.text,
        litri: double.tryParse(_litriController.text.replaceAll(',', '.')),
        euro: double.tryParse(_euroController.text.replaceAll(',', '.')),
        euroPedaggi:
            double.tryParse(_euroPedaggiController.text.replaceAll(',', '.')),
        descDanni: _descrizioneDanniController.text,
        fotoScontrino: _fotoScontrino,
        fotoDanni: _fotoDanni,
        fotoPedaggio: _fotoPedaggio,
      );

      await provider.inizializzaDati();
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text(
                widget.isEmergenza ? "SOS Inviato" : "Restituzione Completata"),
            backgroundColor: Colors.green));
        navigator.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      scaffoldMessenger.showSnackBar(
          SnackBar(content: Text("Errore: $e"), backgroundColor: Colors.red));
    }
  }

  Widget _buildSubmitButton(Color color) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _submitForm,
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: Text(
            widget.isEmergenza
                ? "INVIA SEGNALAZIONE SOS"
                : "CONFERMA RESTITUZIONE",
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
