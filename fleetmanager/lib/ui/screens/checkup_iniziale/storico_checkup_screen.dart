import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:flutter/material.dart';
import 'package:fleetmanager/services/checkup_iniziale_Service.dart';
import 'package:provider/provider.dart';

class StoricoCheckupScreen extends StatefulWidget {
  const StoricoCheckupScreen({super.key});

  @override
  State<StoricoCheckupScreen> createState() => _StoricoCheckupScreenState();
}

class _StoricoCheckupScreenState extends State<StoricoCheckupScreen> {
  String? _targaSelezionata;

  @override
  Widget build(BuildContext context) {
    final veicoli = context.watch<FleetProvider>().veicoli;

    final listaTarghe = veicoli.map((v) => v.targa).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Storico Ispezioni"),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: Column(
        children: [
          // --- DROPDOWN FILTRO TARGA ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _targaSelezionata,
                  hint: const Text("Seleziona un veicolo"),
                  isExpanded: true,
                  icon: const Icon(Icons.filter_list, color: Colors.blueGrey),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text("Mostra tutte le auto"),
                    ),
                    ...listaTarghe.map((targa) => DropdownMenuItem(
                          value: targa,
                          child: Text(targa),
                        )),
                  ],
                  onChanged: (nuovaTarga) {
                    setState(() => _targaSelezionata = nuovaTarga);
                  },
                ),
              ),
            ),
          ),

          // LISTA RISULTATI
          Expanded(
            child: FutureBuilder(
              future:
                  CheckupService().getStoricoCheckup(targa: _targaSelezionata),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final checkups = snapshot.data ?? [];
                if (checkups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 10),
                        Text("Nessun check-up per la targa $_targaSelezionata"),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: checkups.length,
                  itemBuilder: (context, index) =>
                      _buildCheckupCard(checkups[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckupCard(Map<String, dynamic> data) {
    final prenotazione = data['prenotazioni'];
    final String targa = prenotazione != null ? prenotazione['targa'] : 'N/A';

    String dataFormattata = "Data non disponibile";
    if (data['data_check'] != null) {
      dataFormattata = DateTime.parse(data['data_check'])
          .toLocal()
          .toString()
          .substring(0, 16);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration:
              BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
          child: Icon(Icons.fact_check, color: Colors.blue[700]),
        ),
        title: Text("Targa: $targa",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Ispezione del $dataFormattata"),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChecklistStatus(data),
                const Divider(),
                const Text("REPORT FOTOGRAFICO",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _imgPreview(context, data['url_foto_fronte']),
                      _imgPreview(context, data['url_foto_retro']),
                      _imgPreview(context, data['url_foto_dx']),
                      _imgPreview(context, data['url_foto_sx']),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text("NOTE E DANNI",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(data['note_danni'] ?? "Nessuna nota",
                    style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                if (data['url_firma'] != null) ...[
                  const Text("FIRMA:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    color: Colors.white,
                    child: Image.network(data['url_firma'],
                        height: 80, fit: BoxFit.contain),
                  ),
                ],
              ],
            ),
          )
        ],
      ),
    );
  }

// Widget di supporto per vedere se i check erano OK
  Widget _buildChecklistStatus(Map<String, dynamic> data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statusIcon(data['luci_ok'], Icons.lightbulb),
        _statusIcon(data['gomme_ok'], Icons.tire_repair),
        _statusIcon(data['interni_ok'], Icons.cleaning_services),
      ],
    );
  }

  Widget _statusIcon(bool? value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        Icon(
          value == true ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: value == true ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _imgPreview(BuildContext context, String? url) {
    // Aggiunto BuildContext context
    if (url == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue[100]!, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            // --- NAVIGAZIONE VERSO FULL SCREEN ---
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenImagePage(imageUrl: url),
                fullscreenDialog: true,
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                width: 100,
                height: 100,
                child: Icon(Icons.broken_image, color: Colors.red),
              ),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[100],
                  child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white, size: 50),
            ),
          ),
        ),
      ),
    );
  }
}
