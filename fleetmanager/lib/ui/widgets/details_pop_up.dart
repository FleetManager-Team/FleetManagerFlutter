import 'package:flutter/material.dart';
import 'package:fleetmanager/core/theme/index.dart';

class DetailsPopUp extends StatelessWidget {
  final String title;
  final IconData titleIcon;
  final List<Widget> details;
  final List<Widget>? actions;

  final String? extraSectionTitle;
  final Widget? extraContent;

  const DetailsPopUp({
    super.key,
    required this.title,
    required this.titleIcon,
    required this.details,
    this.actions,
    this.extraSectionTitle,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXLarge)),
      title: Row(
        children: [
          Icon(titleIcon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Elenco dettagli principali
            ...details,

            // Sezione Extra con Riquadro
            if (extraSectionTitle != null && extraContent != null) ...[
              const Divider(height: 30),
              Text(
                extraSectionTitle!.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppColors.primary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              // Ecco il riquadro che racchiude l'informazione
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.grey50, // Sfondo leggero
                  borderRadius: BorderRadius.circular(AppSpacing.radiusDefault),
                  border:
                      Border.all(color: AppColors.primaryLight), // Bordino sottile
                ),
                child: extraContent!,
              ),
            ],
          ],
        ),
      ),
      actions: actions,
    );
  }
}
