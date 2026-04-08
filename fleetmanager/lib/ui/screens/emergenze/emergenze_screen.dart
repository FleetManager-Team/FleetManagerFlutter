import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/models/restituzione.dart';
import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/dettaglio_prenotazione_manager.dart';

class EmergenzeScreen extends StatelessWidget {
  const EmergenzeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final df = DateFormat('dd/MM/yyyy HH:mm');

    // 1. Filtro Veicoli Fermi (Manutenzione o Fuori Servizio)
    final veicoliFermi = provider.veicoli
        .where((v) =>
            v.statoVeicolo == StatoVeicolo.inManutenzione ||
            v.statoVeicolo == StatoVeicolo.fuoriServizio)
        .toList();

    final segnalazioniSos =
        provider.restituzioni.where((r) => r.isEmergenza == true).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Centro Emergenze",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => provider.inizializzaDati(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- SEZIONE 1: VEICOLI FERMI ---
                  _buildSectionHeader(
                      "VEICOLI FUORI SERVIZIO", Icons.warning_amber_rounded),
                  if (veicoliFermi.isEmpty)
                    _buildEmptyCard("Nessun veicolo fermo al momento")
                  else
                    ...veicoliFermi.map((v) => _buildVeicoloEmergenzaCard(v)),

                  const SizedBox(height: 24),

                  // --- SEZIONE 2: STORICO SOS ---
                  _buildSectionHeader(
                      "STORICO SEGNALAZIONI SOS", Icons.history),
                  if (segnalazioniSos.isEmpty)
                    _buildEmptyCard("Nessuna segnalazione SOS in archivio")
                  else
                    ...segnalazioniSos.map(
                        (r) => _buildSosHistoryCard(context, r, provider, df)),
                ],
              ),
            ),
    );
  }

  // --- HEADER SEZIONE ---
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.red[900], size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.red[900],
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // --- CARD VEICOLO (Stile VehicleList) ---
  Widget _buildVeicoloEmergenzaCard(Veicolo v) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            v.tipoVeicolo == TipoVeicolo.furgone
                ? Icons.local_shipping
                : Icons.directions_car,
            color: Colors.red[900],
          ),
        ),
        title: Text(
          "${v.marca} ${v.modello}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "Targa: ${v.targa} • ${v.km} km",
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        trailing: _buildStatusChip(v.statoVeicolo),
      ),
    );
  }

  // --- CARD SOS (Stile VehicleList) ---
  Widget _buildSosHistoryCard(BuildContext context, Restituzione r,
      FleetProvider provider, DateFormat df) {
    final prenotazione = provider.prenotazioni
        .firstWhere((p) => p.idPrenotazione == r.idPrenotazione);
    final driver = provider.getDriverDallaPrenotazione(prenotazione);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  DettaglioPrenotazioneManager(prenotazione: prenotazione)),
        ),
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.sos, color: Colors.orange),
        ),
        title: Text(
          "SOS ${prenotazione.targa}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text("Driver: ${driver.nome} ${driver.cognome}",
                style: const TextStyle(fontSize: 13)),
            Text(df.format(r.dataRestituzione),
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      ),
    );
  }

  // --- UTILS ---
  Widget _buildStatusChip(StatoVeicolo stato) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: stato == StatoVeicolo.fuoriServizio
            ? Colors.red[700]
            : Colors.orange[700],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        stato.name.toUpperCase(),
        style: const TextStyle(
            fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            message,
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontStyle: FontStyle.italic),
          ),
        ),
      ),
    );
  }
}
