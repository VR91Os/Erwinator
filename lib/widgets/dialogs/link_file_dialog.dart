import 'package:flutter/material.dart';

import '../../models/project.dart';
import '../../utils/file_type_utils.dart';
import '../../utils/project_file_lookup.dart';
import '../../utils/safe_notify.dart';

// Projektweite Auswahl einer bereits vorhandenen Datei (aus jedem Gewerk),
// um sie mit einer Aufgabe zu verknüpfen - z.B. ein bereits hochgeladenes
// Foto, ohne es ein zweites Mal abzulegen (siehe TaskDetailScreen).
void showLinkFileDialog(
  BuildContext context, {
  required Project project,
  required void Function(String fileEntryId) onPicked,
}) {
  final locations = allFileEntries(project);

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text("Datei verknüpfen"),
        content: SizedBox(
          width: double.maxFinite,
          child: locations.isEmpty
              ? const Text(
                  "Im Projekt sind noch keine Dateien hochgeladen.",
                  style: TextStyle(color: Colors.grey),
                )
              : ListView(
                  shrinkWrap: true,
                  children: locations.map((loc) {
                    return ListTile(
                      leading: Icon(fileTypeIcon(loc.entry.fileType)),
                      title: Text(loc.entry.name),
                      subtitle: Text('${loc.gewerk.name} · ${loc.module.label.isEmpty ? fileTypeLabel(loc.entry.fileType) : loc.module.label}'),
                      onTap: () =>
                          popDialogThen(dialogContext, () => onPicked(loc.entry.id)),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Abbrechen"),
          ),
        ],
      );
    },
  );
}
