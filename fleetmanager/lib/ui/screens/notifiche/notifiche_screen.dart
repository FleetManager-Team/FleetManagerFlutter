import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../provider/fleet_provider.dart';
import '../../../models/enums/tipo_notifica.dart';
import 'package:fleetmanager/core/theme/index.dart';

class NotificheScreen extends StatelessWidget {
  const NotificheScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FleetProvider>();
    final notifiche = provider.notifiche;
    final haNotificheNonLette = notifiche.any((n) => !n.letta);

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text("Centro Notifiche"),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        actions: [
          if (notifiche.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: "Elimina tutte",
              onPressed: () => _confermaSvuota(context, provider),
            ),
            if (haNotificheNonLette)
              SizedBox(
                width: 120,
                child: TextButton(
                  onPressed: () => provider.segnaTutteNotificheComeLette(),
                  child: const Text(
                    "Leggi tutte",
                    style: TextStyle(color: AppColors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                      key: Key("notifica_${n.idNotifica}"),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: AppColors.error,
                        child: const Icon(Icons.delete, color: AppColors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Elimina notifica?"),
                            content: const Text(
                                "Questa azione rimuoverà la notifica definitivamente."),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text("ANNULLA")),
                              ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: AppButtonStyles.elevated(
                                      color: AppColors.error),
                                  child: const Text("ELIMINA")),
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
                        color: n.letta ? Colors.white : AppColors.grey50,
                        elevation: n.letta ? 1 : 3,
                        child: ListTile(
                          // IL TOCCO SEGNA COME LETTO (NON ELIMINA)
                          onTap: n.letta
                              ? null
                              : () =>
                                  provider.segnaNotificaLetta(n.idNotifica!),
                          leading: _getNotificaIcon(n.tipoNotifica),
                          title: Text(
                            n.messaggio,
                            style: TextStyle(
                              fontWeight:
                                  n.letta ? FontWeight.normal : FontWeight.bold,
                              color: n.letta ? AppColors.grey700 : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('dd/MM HH:mm').format(n.dataInvio.toLocal()),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.grey600),
                          ),
                          trailing: n.letta
                              ? const Icon(Icons.done_all,
                                  color: AppColors.success, size: 20)
                              : const Icon(Icons.circle,
                                  color: AppColors.primary, size: 10),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 80, color: AppColors.grey400),
          SizedBox(height: 16),
          Text("Nessuna notifica presente",
              style: TextStyle(fontSize: 18, color: AppColors.grey600)),
        ],
      ),
    );
  }

  Widget _getNotificaIcon(TipoNotifica tipo) {
    switch (tipo) {
      case TipoNotifica.info:
        return const Icon(Icons.info, color: AppColors.primary);
      case TipoNotifica.alert:
        return const Icon(Icons.warning, color: AppColors.error);
      case TipoNotifica.manutenzione:
        return const Icon(Icons.build, color: AppColors.secondary);
      case TipoNotifica.scadenza:
        return const Icon(Icons.timer, color: AppColors.info);
    }
  }

  void _confermaSvuota(BuildContext context, FleetProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Svuota Centro Notifiche"),
        content: const Text("Sei sicuro di voler eliminare tutto?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("ANNULLA")),
          ElevatedButton(
            style: AppButtonStyles.elevated(color: AppColors.error),
            onPressed: () {
              provider.eliminaTutteLeNotifiche();
              Navigator.pop(ctx);
            },
            child: const Text("ELIMINA TUTTO"),
          ),
        ],
      ),
    );
  }
}
