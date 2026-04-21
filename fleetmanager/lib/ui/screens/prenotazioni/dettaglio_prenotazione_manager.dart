import 'package:FleetManager/models/checkup.dart';
import 'package:FleetManager/models/enums/stato_prenotazione.dart';
import 'package:FleetManager/provider/fleet_provider.dart';
import 'package:FleetManager/ui/screens/restituzioni/restituzione_veicolo_screen.dart';
import 'package:flutter/material.dart';
import 'package:FleetManager/core/theme/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/prenotazione.dart';

class DettaglioPrenotazioneManager extends StatelessWidget {
  final Prenotazione prenotazione;
  const DettaglioPrenotazioneManager({super.key, required this.prenotazione});

  /// Recupera i dati distribuiti su più tabelle (Restituzione, Checkup e KM attuali)
  Future<Map<String, dynamic>> _getDatiCompleti() async {
    final client = Supabase.instance.client;

    // Recupero dati di chiusura 
    final resRestituzione = await client
        .from('restituzioni')
        .select()
        .eq('id_prenotazione', prenotazione.idPrenotazione)
        .maybeSingle();

    // Recupero report tecnico (foto carrozzeria, checklist luci/gomme)
    final resCheckup = await client
        .from('checkups')
        .select()
        .eq('id_prenotazione', prenotazione.idPrenotazione)
        .maybeSingle();

    // Recupero km attuali del veicolo per confronto
    final resVeicolo = await client
        .from('veicoli')
        .select('km')
        .eq('targa', prenotazione.targa)
        .single();

    return {
      'restituzione': resRestituzione,
      'checkup':
          resCheckup != null ? CheckupVeicolo.fromJson(resCheckup) : null,
      'km_veicolo': resVeicolo['km'],
    };
  }

  /// Gestisce l'approvazione o il rifiuto di una richiesta
  Future<void> _aggiornaStato(
      BuildContext context, StatoPrenotazione nuovoStato) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<FleetProvider>(context, listen: false);

    try {
      if (nuovoStato == StatoPrenotazione.attiva) {
        await provider.confermaPrenotazione(prenotazione.idPrenotazione);
      } else {
        await provider.annullaPrenotazione(prenotazione.idPrenotazione);
      }

      await provider.inizializzaDati();

      if (navigator.canPop()) navigator.pop();

      messenger.showSnackBar(
        SnackBar(
          content: Text(nuovoStato == StatoPrenotazione.attiva
              ? "Prenotazione approvata"
              : "Prenotazione rifiutata"),
          backgroundColor: nuovoStato == StatoPrenotazione.attiva
              ? AppColors.success
              : AppColors.error,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text("Errore: $e"), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final provider = Provider.of<FleetProvider>(context);
    final utente = provider.utenteLoggato;
    final isManager = utente?.idUtente != prenotazione.idUtente;

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: Text("Dettaglio ${prenotazione.targa}"),
        backgroundColor: AppColors.grey800,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getDatiCompleti(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final dati = snapshot.data;
          final restituzione = dati?['restituzione'];
          final checkup = dati?['checkup'] as CheckupVeicolo?;
          final kmVeicolo = dati?['km_veicolo'] ?? 'N/D';

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // 1. HEADER: Info principali prenotazione e driver
              _buildHeader(context, df, kmVeicolo, provider),
              const SizedBox(height: 20),

              // 2. AZIONI: Solo se la prenotazione è in attesa (Stato Richiesta)
              if (prenotazione.statoPrenotazione ==
                      StatoPrenotazione.richiesta &&
                  isManager) ...[
                _buildConflictWarning(context, provider.prenotazioni),
                _buildManagerActions(context),
              ],

              // 3. STATO ANNULLATO: Messaggio chiaro se la pratica è chiusa negativamente
              if (prenotazione.statoPrenotazione == StatoPrenotazione.annullata)
                _buildStatusCard("Prenotazione annullata", AppColors.error),

              // 4. REPORT TECNICO (CHECKUP): Foto carrozzeria e checklist (NOVITÀ)
              if (checkup != null) ...[
                _buildSectionTitle("Report Tecnico e Ispezione"),
                _buildCheckupSection(context, checkup),
                const SizedBox(height: 16),
              ],

              // 5. DATI RICONSEGNA: Carburante, Km finali, Spese
              if (restituzione != null) ...[
                _buildSectionTitle("Dati di Riconsegna"),
                _buildSezioniRestituzione(context, restituzione, df),
              ] else if (prenotazione.statoPrenotazione ==
                  StatoPrenotazione.attiva)
                _buildNoDataWarning(),

              // 6. AZIONI DRIVER: Tasto per inserire/modificare i dati
              if (!isManager &&
                  prenotazione.statoPrenotazione != StatoPrenotazione.annullata)
                _buildBottoneDriver(context, restituzione),

              // Footer informativo
              if (restituzione != null && !isManager)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text("Puoi modificare i dati in caso di errore",
                        style: TextStyle(
                            color: AppColors.grey500,
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // --- COMPONENTI UI ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
              letterSpacing: 1.1)),
    );
  }

  Widget _buildHeader(BuildContext context, DateFormat df, dynamic kmVeicolo,
      FleetProvider provider) {
    final driver = provider.getDriverDallaPrenotazione(prenotazione);
    Color coloreStato = _getColoreStato(prenotazione.statoPrenotazione);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLarge)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.grey50,
                  radius: 25,
                  child: Icon(Icons.person, color: AppColors.grey800),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prenotazione.targa,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 22)),
                      Text("${driver.nome} ${driver.cognome}",
                          style:
                              const TextStyle(fontSize: 16, color: AppColors.grey700)),
                    ],
                  ),
                ),
                _statusBadge(prenotazione.statoPrenotazione.name.toUpperCase(),
                    coloreStato),
              ],
            ),
            const Divider(height: 30),
            _row("Inizio", df.format(prenotazione.dataInizio.toLocal())),
            _row("Fine", df.format(prenotazione.dataFine.toLocal())),
            _row("KM Iniziali Veicolo", "$kmVeicolo"),
          ],
        ),
      ),
    );
  }

  /// Nuova sezione per visualizzare il report tecnico (CheckupVeicolo)
  Widget _buildCheckupSection(BuildContext context, CheckupVeicolo c) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLarge)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statusIconLabel(c.luciOk, Icons.lightbulb, "Luci"),
                _statusIconLabel(c.gommeOk, Icons.tire_repair, "Gomme"),
                _statusIconLabel(
                    c.interniOk, Icons.cleaning_services, "Interni"),
              ],
            ),
            const Divider(height: 24),
            const Text("REPORT FOTOGRAFICO",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.grey500)),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _imgThumb(context, c.urlFotoFronte),
                  _imgThumb(context, c.urlFotoRetro),
                  _imgThumb(context, c.urlFotoDx),
                  _imgPreview(
                      context, c.urlFotoSx), // Errore corretto: urlFotoSx
                ],
              ),
            ),
            if (c.urlFirma != null) ...[
              const Divider(height: 24),
              const Text("FIRMA DRIVER",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.grey500)),
              const SizedBox(height: 8),
              Image.network(c.urlFirma!, height: 50, fit: BoxFit.contain),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSezioniRestituzione(
      BuildContext context, Map dati, DateFormat df) {
    return Column(
      children: [
        _buildInfoCard("Sintesi Rientro", [
          _row("KM Finali", "${dati['km_finali']}"),
          _row("Carburante", "${dati['livello_carburante']}/16"),
          _row(
              "Data Riconsegna",
              dati['data_restituzione'] != null
                  ? df.format(
                      DateTime.parse(dati['data_restituzione']).toLocal())
                  : "N/D"),
        ]),
        if (dati['rifornimento_effettuato'] == true)
          _buildDetailTile(
              context,
              "Spesa Carburante",
              "${dati['importo_euro']} € | ${dati['litri_carburante']} L",
              dati['url_scontrino'],
              AppColors.grey50),
        if (dati['ha_pedaggi'] == true)
          _buildDetailTile(
              context,
              "Pedaggi / Parcheggi",
              "${dati['importo_pedaggi']} €",
              dati['url_foto_pedaggio'],
              AppColors.secondaryLight),
        if (dati['danni_presenti'] == true)
          _buildDetailTile(
              context,
              "Danni Segnalati",
              dati['descrizione_danni'] ?? "Vedi foto",
              dati['url_foto_danni'],
              AppColors.error.withOpacity(0.1)),
      ],
    );
  }

  // --- UTILITY WIDGETS ---

  Widget _buildDetailTile(BuildContext context, String title, String subtitle,
      String? url, Color bg) {
    return Card(
      color: bg,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
      child: ListTile(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: url != null
            ? GestureDetector(
                onTap: () => _mostraImmagine(context, url),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(url,
                        width: 50, height: 50, fit: BoxFit.cover)),
              )
            : null,
      ),
    );
  }

  Widget _imgThumb(BuildContext context, String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => _mostraImmagine(context, url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _statusIconLabel(bool value, IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.grey300, size: 20),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(value ? Icons.check_circle : Icons.cancel,
                color: value ? AppColors.success : AppColors.error, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXLarge),
          border: Border.all(color: color)),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Color _getColoreStato(StatoPrenotazione stato) {
    switch (stato) {
      case StatoPrenotazione.richiesta:
        return Colors.orange;
      case StatoPrenotazione.attiva:
        return Colors.green;
      case StatoPrenotazione.annullata:
        return Colors.red;
      case StatoPrenotazione.completata:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _row(String label, String val, {Color? colorVal}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.grey600, fontSize: 13)),
            Text(val,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorVal ?? Colors.black87,
                    fontSize: 13)),
          ],
        ),
      );

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLarge)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                  fontSize: 14)),
          const Divider(),
          ...children
        ]),
      ),
    );
  }

  Widget _buildStatusCard(String text, Color color) {
    return Card(
      color: color.withOpacity(0.05),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
          side: BorderSide(color: color.withOpacity(0.2))),
      child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
              child: Text(text,
                  style:
                      TextStyle(color: color, fontWeight: FontWeight.bold)))),
    );
  }

  // --- AZIONI MANAGER ---

  Widget _buildManagerActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _aggiornaStato(context, StatoPrenotazione.attiva),
              icon: const Icon(Icons.check),
              label: const Text("APPROVA"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusDefault))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () =>
                  _aggiornaStato(context, StatoPrenotazione.annullata),
              icon: const Icon(Icons.close),
              label: const Text("RIFIUTA"),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusDefault))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictWarning(BuildContext context, List<Prenotazione> tutte) {
    final df = DateFormat('dd/MM HH:mm');
    final conflitti = tutte
        .where((p) =>
            p.idPrenotazione != prenotazione.idPrenotazione &&
            p.targa == prenotazione.targa &&
            p.statoPrenotazione == StatoPrenotazione.richiesta &&
            prenotazione.dataInizio.toLocal().isBefore(p.dataFine.toLocal()) &&
            prenotazione.dataFine.toLocal().isAfter(p.dataInizio.toLocal()))
        .toList();

    if (conflitti.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
          border: Border.all(color: Colors.amber[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.warning, color: Colors.amber, size: 18),
            SizedBox(width: 8),
            Text("CONFLITTO RILEVATO",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
          ]),
          const SizedBox(height: 4),
          const Text(
              "Approvando questa, le seguenti richieste saranno annullate:",
              style: TextStyle(fontSize: 11)),
          ...conflitti.map((c) => Text(
              "• ${c.idUtente} (${df.format(c.dataInizio.toLocal())})",
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // --- GESTIONE IMMAGINI ---

  void _mostraImmagine(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
                child: Center(child: Image.network(url, fit: BoxFit.contain))),
            Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                    icon:
                        const Icon(Icons.close, color: AppColors.white, size: 30),
                    onPressed: () => Navigator.pop(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataWarning() {
    return Card(
      color: AppColors.secondaryLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(children: [
          Icon(Icons.access_time, color: AppColors.secondary, size: 32),
          SizedBox(height: 10),
          Text("In attesa di Riconsegna",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
          Text("Il driver non ha ancora caricato i dati finali.",
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildBottoneDriver(BuildContext context, Map? dati) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    RestituzioneVeicoloScreen(prenotazione: prenotazione))),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              dati == null ? AppColors.secondary : AppColors.grey700,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
        ),
        icon: Icon(dati == null ? Icons.add_a_photo : Icons.edit_note),
        label: Text(
            dati == null ? "INSERISCI DATI RESTITUZIONE" : "MODIFICA DATI"),
      ),
    );
  }

  // Widget di fallback per l'anteprima foto
  Widget _imgPreview(BuildContext context, String? url) =>
      _imgThumb(context, url);
}
