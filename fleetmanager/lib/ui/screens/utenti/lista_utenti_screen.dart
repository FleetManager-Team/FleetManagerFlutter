import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fleetmanager/models/utente.dart';
import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/core/theme/index.dart';
import 'package:fleetmanager/ui/widgets/app_filter_chip.dart';
import 'package:fleetmanager/ui/widgets/details_pop_up.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  RuoloUtente? filtroRuolo;
  // Non serve più cacheUtenti locale perché leggiamo direttamente dal Provider
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _caricaDati();
  }

  Future<void> _caricaDati() async {
    setState(() => isLoading = true);
    try {
      // Chiamiamo l'inizializzazione dei dati che scarica gli utenti da Supabase
      await context.read<FleetProvider>().inizializzaDati();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore nel caricamento: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usiamo watch per rendere la UI reattiva ai cambiamenti nel database/provider
    final provider = context.watch<FleetProvider>();

    final listaFiltrata = provider.utenti.where((u) {
      return filtroRuolo == null || u.ruoloUtente == filtroRuolo;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text("Gestione Utenti",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _caricaDati,
          )
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : listaFiltrata.isEmpty
                    ? const Center(child: Text("Nessun utente trovato"))
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: listaFiltrata.length,
                        itemBuilder: (context, index) =>
                            _buildUserCard(listaFiltrata[index]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add, color: AppColors.white),
        onPressed: () => _showUserForm(context),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: AppButtonStyles.filterBarHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: AppButtonStyles.filterBarPadding,
        children: [
          _filterChip(null, "TUTTI", Icons.groups_rounded),
          _filterChip(RuoloUtente.driver, "DRIVER", Icons.person),
          _filterChip(
              RuoloUtente.manager, "MANAGER", Icons.admin_panel_settings),
        ],
      ),
    );
  }

  Widget _filterChip(RuoloUtente? ruolo, String label, IconData icon) {
    final isSelected = filtroRuolo == ruolo;
    return Padding(
      padding: const EdgeInsets.only(right: AppButtonStyles.filterChipGap),
      child: AppFilterChip(
        icon: icon,
        label: label,
        selected: isSelected,
        onTap: () => setState(() {
          filtroRuolo = isSelected ? null : ruolo;
        }),
      ),
    );
  }

  Widget _buildUserCard(Utente u) {
    final bool isManager = u.ruoloUtente == RuoloUtente.manager;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
      child: ListTile(
        onTap: () => _showUserDetails(u),
        leading: CircleAvatar(
          backgroundColor:
              isManager ? AppColors.secondaryLight : AppColors.grey50,
          child: Icon(Icons.person,
              color: isManager ? AppColors.secondary : AppColors.primaryDark),
        ),
        title: Text("${u.nome} ${u.cognome}"),
        subtitle: Text("${u.email} • ${u.ruoloUtente.name.toUpperCase()}"),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  void _showUserDetails(Utente u) {
    showDialog(
      context: context,
      builder: (context) => DetailsPopUp(
        title: "${u.nome} ${u.cognome}",
        titleIcon: Icons.person,
        details: [
          _infoRow(Icons.email, "Email", u.email),
          _infoRow(Icons.work, "Ruolo", u.ruoloUtente.name.toUpperCase()),
          if (u.patente != null)
            _infoRow(Icons.credit_card, "Patente", u.patente!),
        ],
        actionsSectionTitle: "Gestione",
        actions: [
          OutlinedButton(
            style: AppButtonStyles.outlined(color: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(u);
            },
            child: const Text("ELIMINA"),
          ),
          OutlinedButton(
            style: AppButtonStyles.outlined(color: AppColors.info),
            onPressed: () {
              Navigator.pop(context);
              _showUserForm(context, u);
            },
            child: const Text("MODIFICA"),
          ),
        ],
      ),
    );
  }

  void _showUserForm(BuildContext context, [Utente? u]) {
    final nomeController = TextEditingController(text: u?.nome ?? "");
    final cognomeController = TextEditingController(text: u?.cognome ?? "");
    final emailController = TextEditingController(text: u?.email ?? "");
    final passwordController = TextEditingController();
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
              Text(u == null ? "Nuovo Utente" : "Modifica Utente",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(labelText: "Nome")),
              TextField(
                  controller: cognomeController,
                  decoration: const InputDecoration(labelText: "Cognome")),
              TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: "Email")),
              if (u == null) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true, // Nasconde i caratteri
                  decoration: const InputDecoration(
                    labelText: "Password Temporanea",
                    hintText: "Minimo 6 caratteri",
                    helperText: "Comunicala al driver per il primo accesso",
                  ),
                ),
              ],
              TextField(
                  controller: patenteController,
                  decoration:
                      const InputDecoration(labelText: "Patente (opzionale)")),
              DropdownButtonFormField<RuoloUtente>(
                initialValue: ruoloSelezionato,
                items: [RuoloUtente.driver, RuoloUtente.manager]
                    .map((r) => DropdownMenuItem(
                        value: r, child: Text(r.name.toUpperCase())))
                    .toList(),
                onChanged: (val) =>
                    setModalState(() => ruoloSelezionato = val!),
                decoration: const InputDecoration(labelText: "Ruolo"),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final provider = context.read<FleetProvider>();

                    // 1. Validazione dei campi obbligatori
                    if (nomeController.text.isEmpty ||
                        emailController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Nome ed Email sono obbligatori")),
                      );
                      return;
                    }

                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    try {
                      if (u == null) {
                        // --- CREAZIONE NUOVO UTENTE ---
                        // Controllo lunghezza password (limite Supabase)
                        if (passwordController.text.length < 6) {
                          messenger.showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "La password deve essere di almeno 6 caratteri")),
                          );
                          return;
                        }

                        // Chiamiamo la funzione che crea sia l'Auth che la riga nel DB
                        await provider.aggiungiNuovoUtente(
                          email: emailController.text.trim(),
                          passwordScelta: passwordController.text,
                          nome: nomeController.text.trim(),
                          cognome: cognomeController.text.trim(),
                          ruolo: ruoloSelezionato.name,
                          patente: patenteController.text.trim(),
                        );
                      } else {
                        // --- MODIFICA UTENTE ESISTENTE ---
                        // Per ora lasciamo la logica che avevi o implementa un update specifico
                        debugPrint(
                            "Logica di modifica da implementare se serve");
                      }

                      // Se tutto è andato bene, chiudiamo il pannello
                      if (mounted) {
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                              content:
                                  Text("Operazione completata con successo!")),
                        );
                      }
                    } catch (e) {
                      // Gestione errori (es: email già registrata o problemi di rete)
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text("Errore: ${e.toString()}")),
                        );
                      }
                    }
                  },
                  child: const Text("SALVA"),
                ),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text("Sei sicuro?"),
        content: Text("L'utente ${u.nome} verrà eliminato definitivamente."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("ANNULLA")),
          ElevatedButton(
            style: AppButtonStyles.elevated(color: AppColors.error),
            onPressed: () async {
              final provider = context.read<FleetProvider>();
              final navigator = Navigator.of(dialogContext);
              await provider.eliminaUtente(u.idUtente);
              if (mounted) {
                navigator.pop();
                // Non serve chiamare _caricaDati() perché eliminaUtente nel provider
                // dovrebbe già gestire la rimozione dalla lista o chiamare notifyListeners()
              }
            },
            child: const Text("ELIMINA"),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.grey400),
          const SizedBox(width: 10),
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
