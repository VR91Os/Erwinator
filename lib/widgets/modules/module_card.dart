import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/project_store.dart';

class ModuleCard extends StatelessWidget {
  final String projectId;
  final String gewerkId;
  final String moduleId;
  final String icon;
  final String defaultTitle;
  final String label;
  final Widget child;

  const ModuleCard({
    super.key,
    required this.projectId,
    required this.gewerkId,
    required this.moduleId,
    required this.icon,
    required this.defaultTitle,
    this.label = '',
    required this.child,
  });

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Modul entfernen?"),
          content: Text(
            '"${label.isEmpty ? defaultTitle : label}" wird inklusive '
            'aller darin erfassten Einträge entfernt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext);
                context
                    .read<ProjectStore>()
                    .removeModule(projectId, gewerkId, moduleId);
              },
              child: const Text("Entfernen"),
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: label);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Modul umbenennen"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: "Name",
              hintText: defaultTitle,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<ProjectStore>().renameModule(
                      projectId,
                      gewerkId,
                      moduleId,
                      controller.text.trim(),
                    );
                Navigator.pop(dialogContext);
              },
              child: const Text("Speichern"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = "$icon ${label.isEmpty ? defaultTitle : label}";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: "Modul umbenennen",
                onPressed: () => _showRenameDialog(context),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: "Modul entfernen",
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}
