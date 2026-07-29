import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fleetmanager/provider/impostazioni_provider.dart';
import 'package:fleetmanager/core/theme/index.dart';

class ImpostazioniManagerScreen extends StatelessWidget {
  const ImpostazioniManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final imp = context.watch<ImpostazioniProvider>();

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text("Impostazioni Azienda",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildSectionHeader("FOTO E DOCUMENTAZIONE"),
          _buildSettingCard(
            icon: Icons.receipt_long,
            title: "Foto scontrino carburante obbligatoria",
            subtitle:
                "Il driver deve fotografare lo scontrino quando effettua rifornimento.",
            value: imp.fotoScontrinoObbligatoria,
            onChanged: imp.setFotoScontrinoObbligatoria,
            activeColor: AppColors.success,
          ),
          _buildSettingCard(
            icon: Icons.car_crash_outlined,
            title: "Foto danni obbligatoria",
            subtitle:
                "Il driver deve fotografare i danni segnalati al momento della restituzione.",
            value: imp.fotoDanniObbligatoria,
            onChanged: imp.setFotoDanniObbligatoria,
            activeColor: AppColors.error,
          ),
          _buildSettingCard(
            icon: Icons.toll_outlined,
            title: "Foto ricevuta pedaggi obbligatoria",
            subtitle:
                "Il driver deve fotografare la ricevuta quando segnala pedaggi o parcheggi.",
            value: imp.fotoPedaggiObbligatoria,
            onChanged: imp.setFotoPedaggiObbligatoria,
            activeColor: Colors.blueAccent,
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("FLUSSO OPERATIVO"),
          _buildSettingCard(
            icon: Icons.checklist_rtl_outlined,
            title: "Checkup iniziale obbligatorio",
            subtitle:
                "Prima di usare il veicolo, il driver deve compilare il modulo di stato iniziale.",
            value: imp.checkupObbligatorio,
            onChanged: imp.setCheckupObbligatorio,
            activeColor: AppColors.primaryDark,
          ),
          _buildSettingCard(
            icon: Icons.approval_outlined,
            title: "Approvazione prenotazioni richiesta",
            subtitle:
                "Le prenotazioni devono essere approvate dal manager prima di diventare attive. Se disabilitato, vengono confermate automaticamente.",
            value: imp.approvazioneRichiesta,
            onChanged: imp.setApprovazioneRichiesta,
            activeColor: AppColors.primaryDark,
          ),
          const SizedBox(height: 20),
          _buildSectionHeader("MODULI AGGIUNTIVI"),
          _buildSettingCard(
            icon: Icons.payments_outlined,
            title: "Modulo pedaggi abilitato",
            subtitle:
                "Mostra la sezione pedaggi/parcheggi nella schermata di restituzione. Disabilitalo se la tua azienda non utilizza autostrade.",
            value: imp.moduloPedaggiAbilitato,
            onChanged: imp.setModuloPedaggiAbilitato,
            activeColor: AppColors.secondary,
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Le impostazioni vengono salvate sul dispositivo e si applicano immediatamente a tutti gli utenti dell'app.",
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.grey500,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
    required Color activeColor,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusDefault)),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (value ? activeColor : AppColors.grey400)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
          child: Icon(icon,
              color: value ? activeColor : AppColors.grey400, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
        ),
        value: value,
        activeThumbColor: activeColor,
        onChanged: onChanged,
        isThreeLine: true,
      ),
    );
  }
}
