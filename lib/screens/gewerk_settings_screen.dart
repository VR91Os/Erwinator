import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/project_store.dart';
import '../widgets/app_bar.dart';

// Optionen für einen einzelnen Gewerk-Reiter: Gewerk umbenennen oder
// löschen. Unterscheidet sich bewusst von den Überblick- und den
// App-weiten Optionen.
class GewerkSettingsScreen extends StatefulWidget {
  final String projectId;
  final String gewerkId;
  final String initialName;

  const GewerkSettingsScreen({
    super.key,
    required this.projectId,
    required this.gewerkId,
    required this.initialName,
  });

  @override
  State<GewerkSettingsScreen> createState() => _GewerkSettingsScreenState();
}

class _GewerkSettingsScreenState extends State<GewerkSettingsScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;
    context.read<ProjectStore>().renameGewerk(
          widget.projectId,
          widget.gewerkId,
          _nameController.text.trim(),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Gespeichert")),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Gewerk löschen?"),
          content: Text(
            '"${widget.initialName}" wird inklusive aller Module und '
            'Aufgaben entfernt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                context
                    .read<ProjectStore>()
                    .removeGewerk(widget.projectId, widget.gewerkId);
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text("Löschen"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar("Optionen – ${widget.initialName}", context, true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "Name des Gewerks"),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text("Speichern"),
            ),
          ),
          const Divider(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text("Gewerk löschen"),
          ),
        ],
      ),
    );
  }
}
