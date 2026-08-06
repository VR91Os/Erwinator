import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/modules/file_module.dart';
import '../../state/project_store.dart';
import '../../utils/id_generator.dart';
import 'module_card.dart';

class FileModuleWidget extends StatelessWidget {
  final String projectId;
  final String gewerkId;
  final FileModule module;

  const FileModuleWidget({
    super.key,
    required this.projectId,
    required this.gewerkId,
    required this.module,
  });

  IconData _iconFor(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'photo':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      projectId: projectId,
      gewerkId: gewerkId,
      moduleId: module.id,
      title: "📁 File-Ablage",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...module.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(_iconFor(entry.fileType), size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "${entry.name} (${entry.versions.length} Version"
                      "${entry.versions.length == 1 ? '' : 'en'})",
                    ),
                  ),
                  if (entry.fileType == 'pdf')
                    IconButton(
                      icon: const Icon(Icons.add_box_outlined, size: 18),
                      tooltip: "Neue Version",
                      onPressed: () => _showNewVersionDialog(context, entry),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _showNewEntryDialog(context),
            child: const Text("➕ Datei-Eintrag hinzufügen"),
          ),
        ],
      ),
    );
  }

  void _showNewEntryDialog(BuildContext context) {
    final nameController = TextEditingController();
    String fileType = 'document';
    final store = context.read<ProjectStore>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Neuer Datei-Eintrag"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Name *"),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: fileType,
                    decoration: const InputDecoration(labelText: "Typ"),
                    items: const [
                      DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                      DropdownMenuItem(value: 'photo', child: Text('Foto')),
                      DropdownMenuItem(value: 'video', child: Text('Video')),
                      DropdownMenuItem(
                          value: 'document', child: Text('Dokument')),
                    ],
                    onChanged: (value) {
                      setDialogState(() => fileType = value ?? 'document');
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Abbrechen"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      return;
                    }
                    final entry = FileEntry(
                      id: newId(),
                      name: nameController.text.trim(),
                      fileType: fileType,
                      versions: [
                        FileVersion(id: newId(), label: "v1"),
                      ],
                    );
                    store.addFileEntry(projectId, gewerkId, module.id, entry);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Hinzufügen"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNewVersionDialog(BuildContext context, FileEntry entry) {
    final labelController = TextEditingController(
      text: "v${entry.versions.length + 1}",
    );
    final store = context.read<ProjectStore>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Neue Version für ${entry.name}"),
          content: TextField(
            controller: labelController,
            decoration: const InputDecoration(labelText: "Bezeichnung"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                if (labelController.text.trim().isEmpty) {
                  return;
                }
                store.addFileVersion(
                  projectId,
                  gewerkId,
                  module.id,
                  entry.id,
                  FileVersion(id: newId(), label: labelController.text.trim()),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text("Hinzufügen"),
            ),
          ],
        );
      },
    );
  }
}
