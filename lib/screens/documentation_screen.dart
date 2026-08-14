import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/documentation_entry.dart';
import '../state/documentation_store.dart';
import '../utils/file_export.dart';
import '../widgets/app_bar.dart';

// Projektübergreifender Dokumentations-Ordner: Fotos/Videos, die beim
// Hochladen bewusst über die Checkbox "Für Dokumentation in eigenen Ordner
// sichern?" hier zusätzlich abgelegt wurden. Bleibt erhalten, auch wenn
// das ursprüngliche Projekt später gelöscht wird.
class DocumentationScreen extends StatefulWidget {
  const DocumentationScreen({super.key});

  @override
  State<DocumentationScreen> createState() => _DocumentationScreenState();
}

class _DocumentationScreenState extends State<DocumentationScreen> {
  String query = '';

  IconData _iconFor(String fileType) =>
      fileType == 'video' ? Icons.videocam : Icons.image;

  Future<void> _download(DocumentationEntry entry) async {
    if (entry.content.isEmpty) return;
    final bytes = base64Decode(entry.content);
    final fileName = entry.extension.isEmpty
        ? entry.name
        : '${entry.name}.${entry.extension}';
    await exportBinaryFile(fileName: fileName, bytes: bytes);
  }

  Future<void> _confirmDelete(BuildContext context, DocumentationEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Eintrag löschen?"),
        content: Text('"${entry.name}" wird aus der Dokumentation entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Abbrechen"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Löschen"),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<DocumentationStore>().removeEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DocumentationStore>();
    final q = query.trim().toLowerCase();
    final results = store.entries.where((e) {
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.projectName.toLowerCase().contains(q) ||
          e.gewerkName.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: buildAppBar("Dokumentation", context, true),
      body: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: "Durchsuchen…",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => query = value),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: results.isEmpty
                        ? Center(
                            child: Text(
                              store.entries.isEmpty
                                  ? "Noch nichts in der Dokumentation. Beim "
                                      "Hochladen eines Fotos/Videos über die "
                                      "Checkbox hinzufügen."
                                  : "Keine Treffer",
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final entry = results[index];
                              final origin = [entry.projectName, entry.gewerkName]
                                  .where((s) => s.isNotEmpty)
                                  .join(' · ');
                              return ListTile(
                                leading: Icon(_iconFor(entry.fileType)),
                                title: Text(entry.name),
                                subtitle: Text(
                                  "${origin.isEmpty ? '' : '$origin · '}"
                                  "${entry.createdBy.isEmpty ? '' : 'von ${entry.createdBy} · '}"
                                  "${entry.createdAt.day}.${entry.createdAt.month}.${entry.createdAt.year}",
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.download_outlined),
                                      tooltip: "Abrufen",
                                      onPressed: () => _download(entry),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: "Löschen",
                                      onPressed: () =>
                                          _confirmDelete(context, entry),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
