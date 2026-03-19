import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fleetmanager/models/utente.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/ui/widgets/details_pop_up.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  RuoloUtente? filtroRuolo;
  String queryRicerca = "";

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();

    // Filtro locale degli utenti
    final listaFiltrata = provider.utenti.where((u) {
      final matchRuolo = filtroRuolo == null || u.ruoloUtente == filtroRuolo;
      final matchRicerca =
          u.nome.toLowerCase().contains(queryRicerca.toLowerCase()) ||
              u.cognome.toLowerCase().contains(queryRicerca.toLowerCase());
      final nonAdmin = u.ruoloUtente !=
          RuoloUtente.admin; // Nascondiamo gli admin dalla gestione
      return matchRuolo && matchRicerca && nonAdmin;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Gestione Utenti",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          Expanded(
            child: listaFiltrata.isEmpty
                ? const Center(child: Text("Nessun utente trovato"))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: listaFiltrata.length,
                    itemBuilder: (context, index) =>
                        _buildUserCard(listaFiltrata[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[900],
        child: const Icon(Icons.person_add, color: Colors.white),
        onPressed: () => _showUserForm(context),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => queryRicerca = val),
            decoration: InputDecoration(
              hintText: "Cerca nome o cognome...",
              prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip(null, "TUTTI"),
                _filterChip(RuoloUtente.driver, "DRIVER"),
                _filterChip(RuoloUtente.manager, "MANAGER"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(RuoloUtente? ruolo, String label) {
    final isSelected = filtroRuolo == ruolo;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.blue[900],
                fontSize: 11,
                fontWeight: FontWeight.bold)),
        selected: isSelected,
        selectedColor: Colors.blue[900],
        onSelected: (val) => setState(() => filtroRuolo = val ? ruolo : null),
      ),
    );
  }

  Widget _buildUserCard(Utente u) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _showUserDetails(u),
        leading: CircleAvatar(
          backgroundColor: u.ruoloUtente == RuoloUtente.manager
              ? Colors.orange[50]
              : Colors.blue[50],
          child: Icon(Icons.person,
              color: u.ruoloUtente == RuoloUtente.manager
                  ? Colors.orange[800]
                  : Colors.blue[800]),
        ),
        title: Text("${u.nome} ${u.cognome}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(u.email,
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      ),
    );
  }

  void _showUserDetails(Utente u) {
    final provider = context.read<FleetProvider>();

    List<Prenotazione> future = provider.prenotazioni
        .where((p) =>
            p.idUtente == u.idUtente &&
            p.statoPrenotazione != StatoPrenotazione.annullata &&
            p.dataFine.isAfter(DateTime.now()))
        .toList();

    future.sort((a, b) => a.dataInizio.compareTo(b.dataInizio));
    Prenotazione? prossima = future.isNotEmpty ? future.first : null;

    showDialog(
      context: context,
      builder: (context) => DetailsPopUp(
        title: "${u.nome} ${u.cognome}",
        titleIcon: Icons.person_pin,
        details: [
          _detailRow(Icons.email, "Email", u.email),
          _detailRow(Icons.work, "Ruolo", u.ruoloUtente.name.toUpperCase()),
          if (u.patente != null && u.patente!.isNotEmpty)
            _detailRow(Icons.credit_card, "Patente", u.patente!),
        ],
        // Sezione Extra (stesso stile box azzurro/verde dei veicoli)
        extraSectionTitle: "PROSSIMO IMPEGNO",
        extraContent: prossima != null
            ? Column(
                children: [
                  _detailRow(Icons.directions_car, "Veicolo", prossima.targa),
                  _detailRow(Icons.event, "Inizio",
                      DateFormat('dd/MM HH:mm').format(prossima.dataInizio)),
                  _detailRow(Icons.event_available, "Fine",
                      DateFormat('dd/MM HH:mm').format(prossima.dataFine)),
                ],
              )
            : const Text(
                "Nessun impegno futuro per questo utente.",
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.green,
                    fontStyle: FontStyle.italic),
              ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(u);
            },
            child: const Text("ELIMINA", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
            onPressed: () {
              Navigator.pop(context);
              _showUserForm(context, u);
            },
            child:
                const Text("MODIFICA", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Helper per le righe di dettaglio
  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey[400]),
          const SizedBox(width: 10),
          Text("$label: ",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  // --- FORM DI CREAZIONE/MODIFICA ---

  void _showUserForm(BuildContext context, [Utente? u]) {
    final nomeController = TextEditingController(text: u?.nome ?? "");
    final cognomeController = TextEditingController(text: u?.cognome ?? "");
    final emailController = TextEditingController(text: u?.email ?? "");
    final patenteController = TextEditingController(text: u?.patente ?? "");
    RuoloUtente ruoloSelezionato = u?.ruoloUtente ?? RuoloUtente.driver;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 15),
              Text(u == null ? "Nuovo Utente" : "Modifica Utente",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                      labelText: "Nome",
                      prefixIcon: Icon(Icons.person_outline))),
              TextField(
                  controller: cognomeController,
                  decoration: const InputDecoration(
                      labelText: "Cognome",
                      prefixIcon: Icon(Icons.person_outline))),
              TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email_outlined))),
              TextField(
                  controller: patenteController,
                  decoration: const InputDecoration(
                      labelText: "Patente (opzionale)",
                      prefixIcon: Icon(Icons.credit_card))),
              const SizedBox(height: 10),
              DropdownButtonFormField<RuoloUtente>(
                value: ruoloSelezionato,
                items: [RuoloUtente.driver, RuoloUtente.manager]
                    .map((r) => DropdownMenuItem(
                        value: r, child: Text(r.name.toUpperCase())))
                    .toList(),
                onChanged: (val) =>
                    setModalState(() => ruoloSelezionato = val!),
                decoration: const InputDecoration(
                    labelText: "Ruolo", prefixIcon: Icon(Icons.work_outline)),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blue[900],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  // Qui andrebbe la logica di chiamata al Provider:
                  // if (u == null) provider.aggiungiUtente(...) else provider.aggiornaUtente(...)
                  Navigator.pop(context);
                },
                child: const Text("SALVA UTENTE",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DIALOG DI CONFERMA ELIMINAZIONE ---

  void _confirmDelete(Utente u) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Elimina Utente"),
        content: Text(
            "Sei sicuro di voler eliminare ${u.nome} ${u.cognome}? Questa azione non è reversibile."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ANNULLA")),
          TextButton(
            onPressed: () async {
              await context.read<FleetProvider>().eliminaUtente(u.idUtente);
              if (mounted) Navigator.pop(context);
            },
            child: const Text("ELIMINA",
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
