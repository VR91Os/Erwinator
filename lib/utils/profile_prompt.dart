import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/settings_screen.dart';
import '../state/settings_store.dart';

// Beim ersten Teilen/Beitreten prüfen, ob ein Name hinterlegt ist – erst
// daraus wird das Namenskürzel für die Verlaufs-Anzeige automatisch erzeugt.
// Gibt true zurück, wenn fortgefahren werden soll.
Future<bool> ensureProfileForSharing(BuildContext context) async {
  final settings = context.read<SettingsStore>().settings;
  if (settings.userName.trim().isNotEmpty) return true;

  final goToSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Profil vervollständigen"),
      content: const Text(
        "Damit dein Namenskürzel automatisch erzeugt werden kann, hinterlege "
        "zuerst deinen Namen in den Einstellungen.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Trotzdem fortfahren"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text("Zu den Einstellungen"),
        ),
      ],
    ),
  );

  if (goToSettings != true) return true;
  if (!context.mounted) return false;

  await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const SettingsScreen()),
  );
  if (!context.mounted) return false;
  return context.read<SettingsStore>().settings.userName.trim().isNotEmpty;
}
