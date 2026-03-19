import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fleetmanager/models/utente.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  RuoloUtente? filtroRuolo;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Gestione Utenti", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<Utente>>(
              future: provider.getTuttiDriver(), // Assicurati che nel provider restituisca tutti
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final utenti = snapshot.data ?? [];
                // Applichiamo il filtro driver/manager
                final mostrati = filtroRuolo == null 
                    ? utenti 
                    : utenti.where((u) => u.ruoloUtente == filtroRuolo).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: mostrati.length,
                  itemBuilder: (context, index) => _buildUserCard(mostrati[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[900],
        child: const Icon(Icons.person_add, color: Colors.white),
        onPressed: () => _showUserForm(context), // Nuovo utente (vuoto)
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _filterChip(null, "TUTTI"),
          _filterChip(RuoloUtente.driver, "DRIVER"),
          _filterChip(RuoloUtente.manager, "MANAGER"),
        ],
      ),
    );
  }

  Widget _filterChip(RuoloUtente? ruolo, String label) {
    final isSelected = filtroRuolo == ruolo;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.blue[900])),
        selected: isSelected,
        selectedColor: Colors.blue[900],
        onSelected: (val) => setState(() => filtroRuolo = val ? ruolo : null),
      ),
    );
  }

  Widget _buildUserCard(Utente u) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _showUserDetails(u),
        leading: CircleAvatar(
          backgroundColor: u.ruoloUtente == RuoloUtente.manager ? Colors.orange[100] : Colors.blue[100],
          child: Icon(Icons.person, color: u.ruoloUtente == RuoloUtente.manager ? Colors.orange[800] : Colors.blue[800]),
        ),
        title: Text("${u.nome} ${u.cognome}"),
        subtitle: Text(u.email),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  void _showUserDetails(Utente u) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${u.nome} ${u.cognome}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow(Icons.email, "Email", u.email),
            _infoRow(Icons.work, "Ruolo", u.ruoloUtente.name.toUpperCase()),
            if (u.patente != null) _infoRow(Icons.credit_card, "Patente", u.patente!),
          ],
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
            onPressed: () {
              Navigator.pop(context);
              _showUserForm(context, u); // MODIFICA: Passiamo l'utente esistente
            },
            child: const Text("MODIFICA"),
          ),
        ],
      ),
    );
  }

  // --- FORM DI MODIFICA/INSERIMENTO ---
  void _showUserForm(BuildContext context, [Utente? u]) {
    // Inizializziamo i controller con i dati dell'utente se presente (u != null)
    final nomeController = TextEditingController(text: u?.nome ?? "");
    final cognomeController = TextEditingController(text: u?.cognome ?? "");
    final emailController = TextEditingController(text: u?.email ?? "");
    final patenteController = TextEditingController(text: u?.patente ?? "");
    RuoloUtente ruoloSelezionato = u?.ruoloUtente ?? RuoloUtente.driver;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder( // Necessario per aggiornare il dropdown nel BottomSheet
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(u == null ? "Nuovo Utente" : "Modifica Utente", 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(controller: nomeController, decoration: const InputDecoration(labelText: "Nome")),
              TextField(controller: cognomeController, decoration: const InputDecoration(labelText: "Cognome")),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
              TextField(controller: patenteController, decoration: const InputDecoration(labelText: "Patente (opzionale)")),
              DropdownButtonFormField<RuoloUtente>(
                value: ruoloSelezionato,
                items: [RuoloUtente.driver, RuoloUtente.manager].map((r) => 
                  DropdownMenuItem(value: r, child: Text(r.name.toUpperCase()))).toList(),
                onChanged: (val) => setModalState(() => ruoloSelezionato = val!),
                decoration: const InputDecoration(labelText: "Ruolo"),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue[900]),
                onPressed: () async {
                  // Qui andrebbe la logica di salvataggio del provider
                  // provider.aggiornaUtente(...) o provider.creaUtente(...)
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(u == null ? "Utente creato" : "Utente aggiornato"))
                  );
                },
                child: Text("SALVA", style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Utente u) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sei sicuro?"),
        content: Text("L'utente ${u.nome} verrà eliminato definitivamente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULLA")),
          TextButton(
            onPressed: () async {
              await context.read<FleetProvider>().eliminaUtente(u.idUtente);
              if (mounted) Navigator.pop(context);
            },
            child: const Text("ELIMINA", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue[900]),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}