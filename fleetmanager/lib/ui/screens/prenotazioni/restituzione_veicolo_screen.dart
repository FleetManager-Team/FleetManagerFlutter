import 'dart:io';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/services/restituzione_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:provider/provider.dart';

class RestituzioneVeicoloScreen extends StatefulWidget {
  final Prenotazione prenotazione;

  const RestituzioneVeicoloScreen({super.key, required this.prenotazione});

  @override
  State<RestituzioneVeicoloScreen> createState() =>
      _RestituzioneVeicoloScreenState();
}

class _RestituzioneVeicoloScreenState extends State<RestituzioneVeicoloScreen> {
  final _formKey = GlobalKey<FormState>();

  // Dati del Veicolo recuperati all'avvio
  dynamic _veicolo; // Qui salviamo l'intero oggetto Veicolo
  bool _isLoading = true;

  // Controller
  late TextEditingController _kmController;
  final _litriController = TextEditingController();
  final _euroController = TextEditingController();
  final _descrizioneDanniController = TextEditingController();

  double _livelloCarburante = 16.0;
  bool _rifornimentoEffettuato = false;
  bool _danniPresenti = false;

  XFile? _fotoScontrino;
  XFile? _fotoDanni;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _kmController = TextEditingController(text: "Caricamento...");
    _recuperaDatiVeicolo();
  }

  // LOGICA DI RECUPERO OGGETTO VEICOLO
  Future<void> _recuperaDatiVeicolo() async {
    try {
      // Usiamo il FleetProvider che è già nel tuo main.dart
      final fleetProvider = Provider.of<FleetProvider>(context, listen: false);

      // Recuperiamo l'oggetto veicolo
      final vFound =
          await fleetProvider.getVeicoloDallaTarga(widget.prenotazione.targa);

      if (mounted) {
        setState(() {
          _veicolo = vFound;
          if (_veicolo != null) {
            _kmController.text = _veicolo!.km.toString();
          } else {
            _kmController.text = "Non trovato";
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Errore: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _kmController.dispose();
    _litriController.dispose();
    _euroController.dispose();
    _descrizioneDanniController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Restituzione Veicolo"),
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF388E3C)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVehicleHeader(),
                    const SizedBox(height: 25),
                    const Text("Dati di rientro",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),

                    // Chilometri con validazione basata sul veicolo reale
                    TextFormField(
                      controller: _kmController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Chilometri attuali",
                        prefixIcon: const Icon(Icons.speed),
                        helperText: _veicolo != null
                            ? "KM registrati: ${_veicolo!.km}"
                            : null,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Inserisci i KM";
                        final n = int.tryParse(v);
                        if (n == null) return "Inserisci un numero valido";
                        if (_veicolo != null && n < _veicolo!.km) {
                          return "I KM non possono essere inferiori a ${_veicolo!.km}";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 25),

                    const Text("Livello Carburante",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    _buildFuelSelector(),

                    SwitchListTile(
                      title: const Text("Hai fatto rifornimento?"),
                      value: _rifornimentoEffettuato,
                      activeColor: const Color(0xFF388E3C),
                      onChanged: (val) =>
                          setState(() => _rifornimentoEffettuato = val),
                    ),

                    if (_rifornimentoEffettuato) ...[
                      Row(
                        children: [
                          Expanded(
                              child: _buildTextField(_litriController, "Litri",
                                  Icons.local_gas_station)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _buildTextField(
                                  _euroController, "Importo Euro", Icons.euro)),
                        ],
                      ),
                      _buildPhotoSelector(
                          "Foto Scontrino", _fotoScontrino, false),
                    ],

                    const Divider(height: 40),

                    SwitchListTile(
                      title: const Text("Sono presenti nuovi danni?"),
                      value: _danniPresenti,
                      activeColor: Colors.red,
                      onChanged: (val) => setState(() => _danniPresenti = val),
                    ),

                    if (_danniPresenti) ...[
                      TextFormField(
                        controller: _descrizioneDanniController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Descrizione danni",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      _buildPhotoSelector("Foto Danno", _fotoDanni, true),
                    ],

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF388E3C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("CONFERMA RESTITUZIONE",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // HEADER DINAMICO: Usa i dati del veicolo se trovato
  Widget _buildVehicleHeader() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!)),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: Color(0xFF388E3C), size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _veicolo != null
                        ? "${_veicolo!.marca} ${_veicolo!.modello}"
                        : "Veicolo non identificato",
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

  // Metodi Helper (Slider, TextField, PhotoSelector...)
  Widget _buildFuelSelector() {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 18.0),
            activeTrackColor: const Color(0xFF388E3C),
            thumbColor: const Color(0xFF388E3C),
          ),
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
      TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _buildPhotoSelector(String label, XFile? file, bool isDanni) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(file == null ? Icons.add_a_photo : Icons.check_circle,
          color: file == null ? Colors.grey : Colors.green),
      title: Text(label),
      trailing: file != null
          ? (kIsWeb
              ? Image.network(file.path,
                  width: 40, height: 40, fit: BoxFit.cover)
              : Image.file(File(file.path),
                  width: 40, height: 40, fit: BoxFit.cover))
          : const Icon(Icons.chevron_right),
      onTap: () => _prendiFoto(context, isDanni),
    );
  }

Future<void> _prendiFoto(BuildContext context, bool isDanni) async {
  try {
    // Evitiamo il crash su Desktop/Web forzando la gallery
    final source = (kIsWeb || Platform.isWindows || Platform.isMacOS) 
        ? ImageSource.gallery 
        : ImageSource.camera;

    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 50,
    );
    
    if (image != null) {
      setState(() {
        if (isDanni) _fotoDanni = image;
        else _fotoScontrino = image;
      });
    }
  } catch (e) {
    debugPrint("Errore fotocamera: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Impossibile aprire la sorgente: $e"))
    );
  }
}

  void _submitForm() async {
    // 1. Validazione dei campi (KM e campi obbligatori)
    if (!_formKey.currentState!.validate()) return;

    // 2. Controllo coerenza foto scontrino se ha dichiarato rifornimento
    if (_rifornimentoEffettuato && _fotoScontrino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Per favore, scatta una foto allo scontrino del rifornimento.")),
      );
      return;
    }

    // 3. Avvio caricamento
    setState(() => _isLoading = true);

    try {
      // Istanza del service (puoi anche metterlo come variabile di classe)
      final restituzioneService = RestituzioneService();

      // 4. Chiamata al database tramite il Service
      await restituzioneService.completaRestituzione(
        idPrenotazione: widget.prenotazione.idPrenotazione,
        targa: widget.prenotazione.targa,
        kmFinali: int.parse(_kmController.text),
        livelloCarburante: _livelloCarburante,
        rifornimento: _rifornimentoEffettuato,
        haDanni: _danniPresenti,
        litri: double.tryParse(_litriController.text.replaceAll(',', '.')),
        euro: double.tryParse(_euroController.text.replaceAll(',', '.')),
        descDanni: _danniPresenti ? _descrizioneDanniController.text : null,
        fotoScontrino: _fotoScontrino,
        fotoDanni: _fotoDanni,
      );

      // 5. Successo! Aggiorniamo lo stato globale e torniamo indietro
      if (mounted) {
        // Refresh dei dati nel Provider (così la prenotazione sparisce da "attive")
        await Provider.of<FleetProvider>(context, listen: false)
            .inizializzaDati();

        Navigator.pop(context); // Chiude la schermata

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Veicolo restituito correttamente. Grazie!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // 6. Gestione Errori
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Errore durante il salvataggio: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
