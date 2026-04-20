import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/core/theme/index.dart';
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
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text("Centro Emergenze",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.error,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => provider.inizializzaDati(),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
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
          Icon(icon, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: AppColors.error,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
          ),
          child: Icon(
            v.tipoVeicolo == TipoVeicolo.furgone
                ? Icons.local_shipping
                : Icons.directions_car,
            color: AppColors.error,
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
            style: TextStyle(color: AppColors.grey600, fontSize: 13),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  DettaglioPrenotazioneManager(prenotazione: prenotazione)),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
          ),
          child: const Icon(Icons.sos, color: AppColors.secondary),
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
                style: TextStyle(fontSize: 11, color: AppColors.grey500)),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: AppColors.grey400),
      ),
    );
  }

  // --- UTILS ---
  Widget _buildStatusChip(StatoVeicolo stato) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: stato == StatoVeicolo.fuoriServizio
            ? AppColors.error
            : AppColors.secondary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
      ),
      child: Text(
        stato.name.toUpperCase(),
        style: const TextStyle(
            fontSize: 9, color: AppColors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Text(
            message,
            style: TextStyle(
                color: AppColors.grey500,
                fontSize: 13,
                fontStyle: FontStyle.italic),
          ),
        ),
      ),
    );
  }
}
