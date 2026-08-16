import 'package:flutter/material.dart';

// Ab dieser Größe wird vor dem Speichern gewarnt, da der Dateiinhalt mit
// den Projektdaten synchronisiert wird und große Dateien (v.a. Videos)
// Speicherplatz und Sync-Geschwindigkeit spürbar beeinträchtigen können.
const largeFileWarningBytes = 15 * 1024 * 1024;

Future<bool> confirmLargeFile(BuildContext context, int byteSize) async {
  if (byteSize <= largeFileWarningBytes) return true;
  final mb = (byteSize / (1024 * 1024)).toStringAsFixed(1);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Große Datei"),
      content: Text(
        "Diese Datei ist $mb MB groß. Sie wird mit den Projektdaten "
        "synchronisiert und kann Speicherplatz sowie Sync-Geschwindigkeit "
        "für alle Projekt-Mitglieder spürbar beeinträchtigen. Trotzdem "
        "hochladen?",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text("Trotzdem hochladen"),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

void showFileTooLargeSnackBar(
    BuildContext context, int sizeBytes, int maxSizeBytes) {
  final mb = (sizeBytes / (1024 * 1024)).toStringAsFixed(0);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        "Datei ist mit $mb MB zu groß (Obergrenze "
        "${maxSizeBytes ~/ (1024 * 1024)} MB).",
      ),
    ),
  );
}
