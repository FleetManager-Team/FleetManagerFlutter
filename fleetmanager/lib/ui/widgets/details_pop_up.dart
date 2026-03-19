import 'package:flutter/material.dart';

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(titleIcon, color: Colors.blue[900]),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.blue[900],
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              // Ecco il riquadro che racchiude l'informazione
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50], // Sfondo leggero
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.blue[100]!), // Bordino sottile
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
