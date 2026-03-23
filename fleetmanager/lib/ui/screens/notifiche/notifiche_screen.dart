import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../provider/fleet_provider.dart';
import '../../../models/enums/tipo_notifica.dart';

class NotificheScreen extends StatelessWidget {
  const NotificheScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final notifiche = provider.notifiche;
    final haNotificheNonLette = notifiche.any((n) => !n.letta);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Centro Notifiche"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          if (notifiche.isNotEmpty) ...[
            // TASTO ELIMINA TUTTE
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: "Elimina tutte",
              onPressed: () => _confermaSvuota(context, provider),
            ),
            // TASTO LEGGI TUTTE
            if (haNotificheNonLette)
              TextButton(
                onPressed: () => provider.segnaTutteNotificheComeLette(),
                child: const Text("Leggi tutte",
                    style: TextStyle(color: Colors.white)),
              ),
          ]
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifiche.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: notifiche.length,
                  itemBuilder: (context, index) {
                    final n = notifiche[index];

                    return Dismissible(
                      key: Key(n.idNotifica.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        // Conferma prima di eliminare con lo swipe
                        return await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Elimina notifica?"),
                            content: const Text(
                                "Questa azione non può essere annullata."),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text("ANNULLA")),
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text("ELIMINA",
                                      style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        provider.eliminaNotifica(n.idNotifica!);
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        color: n.letta ? Colors.white : Colors.blue[50],
                        elevation: n.letta ? 1 : 3,
                        child: ListTile(
                          leading: _getNotificaIcon(n.tipoNotifica),
                          title: Text(
                            n.messaggio,
                            style: TextStyle(
                              fontWeight:
                                  n.letta ? FontWeight.normal : FontWeight.bold,
                              color: n.letta ? Colors.grey[700] : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('dd/MM HH:mm').format(n.dataInvio),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: n.letta
                              ? const Icon(Icons.done_all,
                                  color: Colors.green, size: 20)
                              : IconButton(
                                  icon: const Icon(Icons.mark_email_read,
                                      color: Colors.blue),
                                  onPressed: () => provider
                                      .segnaNotificaLetta(n.idNotifica!),
                                  tooltip: "Segna come letta",
                                ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  // Widget mostrato quando non ci sono notifiche
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("Nessuna notifica presente",
              style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // Icone basate sul tipo di notifica
  Widget _getNotificaIcon(TipoNotifica tipo) {
    switch (tipo) {
      case TipoNotifica.info:
        return const Icon(Icons.info, color: Colors.blue);
      case TipoNotifica.alert:
        return const Icon(Icons.warning, color: Colors.red);
      case TipoNotifica.manutenzione:
        return const Icon(Icons.build, color: Colors.orange);
      case TipoNotifica.scadenza:
        return const Icon(Icons.timer, color: Colors.purple);
    }
  }

  // Dialog di conferma per svuotare tutto il centro notifiche
  void _confermaSvuota(BuildContext context, FleetProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Svuota Centro Notifiche"),
        content: const Text(
            "Sei sicuro di voler eliminare definitivamente tutte le notifiche?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ANNULLA"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.eliminaTutteLeNotifiche();
              Navigator.pop(ctx);
            },
            child: const Text("ELIMINA TUTTO",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
