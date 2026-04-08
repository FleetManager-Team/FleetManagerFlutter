import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Per kIsWeb
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/services/checkup_iniziale_Service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckingVeicoloScreen extends StatefulWidget {
  final int idPrenotazione;
  final String targa;

  const CheckingVeicoloScreen(
      {super.key, required this.idPrenotazione, required this.targa});

  @override
  State<CheckingVeicoloScreen> createState() => _CheckingVeicoloScreenState();
}

class _CheckingVeicoloScreenState extends State<CheckingVeicoloScreen> {
  bool _isSending = false;

  // Stato Foto (Utilizziamo XFile come nella classe Restituzione)
  XFile? _fFronte, _fRetro, _fDx, _fSx;

  // Stato Checklist
  bool _luci = true;
  bool _gomme = true;
  bool _pulizia = true;

  final TextEditingController _noteController = TextEditingController();

  // Controller Firma
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _noteController.dispose();
    _sigController.dispose();
    super.dispose();
  }

  // --- LOGICA GESTIONE FOTO (COPIATA DA RESTITUZIONE) ---

  Future<void> _prendiFoto(String lato) async {
    if (kIsWeb) {
      _eseguiPick(ImageSource.gallery, lato);
      return;
    }
    showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galleria'),
                  onTap: () {
                    _eseguiPick(ImageSource.gallery, lato);
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Fotocamera'),
                  onTap: () {
                    _eseguiPick(ImageSource.camera, lato);
                    Navigator.pop(context);
                  }),
            ])));
  }

  Future<void> _eseguiPick(ImageSource source, String lato) async {
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 50, // Stessa qualità del tuo codice originale
    );
    if (image != null) {
      setState(() {
        if (lato == "fronte") _fFronte = image;
        if (lato == "retro") _fRetro = image;
        if (lato == "destra") _fDx = image;
        if (lato == "sinistra") _fSx = image;
      });
    }
  }

  Widget _buildPreview(XFile? file) {
    if (file == null) return const Icon(Icons.camera_alt, color: Colors.grey);

    // Anteprima differenziata per Web/Mobile per evitare errori di path
    if (kIsWeb) {
      return Image.network(file.path, fit: BoxFit.cover);
    } else {
      return Image.file(File(file.path), fit: BoxFit.cover);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Check-up ${widget.targa}"),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      body: _isSending
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 20),
                  _buildSectionTitle("1. ISPEZIONE FOTOGRAFICA (4 LATI)"),
                  _buildPhotoGrid(),
                  const SizedBox(height: 20),
                  _buildSectionTitle("2. CHECKLIST TECNICA"),
                  _buildTechnicalChecklist(),
                  const SizedBox(height: 20),
                  _buildSectionTitle("3. NOTE E DANNI"),
                  _buildNoteField(),
                  const SizedBox(height: 20),
                  _buildSectionTitle("4. FIRMA CONDUCENTE"),
                  _buildSignatureArea(),
                  const SizedBox(height: 30),
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  // --- COMPONENTI UI ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
              fontSize: 12)),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.info_outline, color: Colors.blue),
        title: Text("Prenotazione #${widget.idPrenotazione}"),
        subtitle: Text("Veicolo targa: ${widget.targa}"),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _photoBox("FRONTE", _fFronte, "fronte"),
        _photoBox("RETRO", _fRetro, "retro"),
        _photoBox("LATO DX", _fDx, "destra"),
        _photoBox("LATO SX", _fSx, "sinistra"),
      ],
    );
  }

  Widget _photoBox(String label, XFile? file, String lato) {
    return GestureDetector(
      onTap: () => _prendiFoto(lato),
      child: Container(
        clipBehavior:
            Clip.antiAlias, // Assicura che l'immagine segua i bordi arrotondati
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: file != null ? Colors.green : Colors.grey[300]!),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPreview(file),
            if (file == null)
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40), // Spazio per l'icona
                    Text(label,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            if (file != null)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalChecklist() {
    return Card(
      child: Column(
        children: [
          CheckboxListTile(
            title: const Text("Luci e Frecce OK"),
            value: _luci,
            onChanged: (v) => setState(() => _luci = v!),
            activeColor: Colors.green,
          ),
          CheckboxListTile(
            title: const Text("Pneumatici a norma"),
            value: _gomme,
            onChanged: (v) => setState(() => _gomme = v!),
            activeColor: Colors.green,
          ),
          CheckboxListTile(
            title: const Text("Pulizia interna OK"),
            value: _pulizia,
            onChanged: (v) => setState(() => _pulizia = v!),
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: "Descrivi eventuali danni preesistenti...",
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSignatureArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Signature(
            controller: _sigController,
            height: 150,
            backgroundColor: Colors.transparent,
          ),
          Divider(height: 1, color: Colors.grey[300]),
          TextButton.icon(
            onPressed: () => _sigController.clear(),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text("Cancella firma"),
          )
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueGrey[800],
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _submitForm,
        child: const Text("INVIA ISPEZIONE",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- LOGICA DI INVIO ---

  Future<void> _submitForm() async {
    // Validazione foto
    if (_fFronte == null || _fRetro == null || _fDx == null || _fSx == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Scatta tutte le 4 foto perimetrali")),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final Uint8List? signature = await _sigController.toPngBytes();

      // A. CARICA FOTO E DATI
      await CheckupService().inviaCheckupCompleto(
        idPrenotazione: widget.idPrenotazione,
        targa: widget.targa,
        fotoPerimetrali: [_fFronte, _fRetro, _fDx, _fSx],
        luci: _luci,
        gomme: _gomme,
        interni: _pulizia,
        note: _noteController.text,
        firmaBytes: signature,
      );

      // B. CAMBIA LO STATO DELLA PRENOTAZIONE
      // Nota: usiamo 'attiva' per far scattare il cambio UI nel provider
      await Supabase.instance.client.from('prenotazioni').update(
          {'stato': 'attiva'}).eq('id_prenotazione', widget.idPrenotazione);

      // C. AGGIORNA IL PROVIDER
      if (mounted) {
        await context.read<FleetProvider>().inizializzaDati();
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Check-up completato! Buon viaggio."),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}
