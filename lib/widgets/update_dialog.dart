import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_check_service.dart';

// Gemeinsamer "Update verfügbar"-Dialog, genutzt vom stillen Start-Check
// (start_screen.dart) und dem manuellen Check in den Einstellungen
// (settings_screen.dart) - ein Verhalten statt zwei fast identischer,
// unabhängig driftender Kopien.
void showUpdateAvailableDialog(BuildContext context, UpdateInfo update) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Update verfügbar"),
      content: Text(
        "Version ${update.version} ist verfügbar. Jetzt herunterladen? "
        "Die Datei wird im Browser geladen, danach antippen zum "
        "Installieren.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Später"),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            final launched = await launchUrl(Uri.parse(update.downloadUrl));
            if (!launched && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Download konnte nicht gestartet werden."),
                ),
              );
            }
          },
          child: const Text("Herunterladen"),
        ),
      ],
    ),
  );
}
