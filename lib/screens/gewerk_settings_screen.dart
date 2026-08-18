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
    final store = context.watch<ProjectStore>();
    final project =
        store.projects.firstWhere((p) => p.id == widget.projectId);

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
          // ✅ Modul-Optionen gelten projektweit (nicht nur für dieses
          // Gewerk), leben aber hier statt im Überblick, da sie die Module
          // betreffen, die man in einem Gewerk-Reiter anlegt.
          const Divider(height: 40),
          const Text(
            "Kontakt-Optionen",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Ist die Option aus, bleibt das Kontakt-Modul auf Name und "
            "Telefonnummer beschränkt. Aktiviert zeigt jede Person "
            "zusätzlich ein Email-Feld (manuell hinzufügen und bei "
            "bestehenden Personen).",
            style: TextStyle(color: Colors.grey),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Auch Email angeben"),
            value: project.showContactEmail,
            onChanged: (value) => store.updateShowContactEmail(
              widget.projectId,
              enabled: value ?? false,
            ),
          ),
          const Divider(height: 40),
          const Text(
            "Todo-Listen-Optionen",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            "Fälligkeit verschieben",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            "Um wie viele Tage der zusätzliche Verschieben-Button an "
            "Aufgaben die Fälligkeit vorschlägt. Landet das Ergebnis auf "
            "einem Sonntag oder Feiertag (siehe App-Optionen -> "
            "Feiertage), wird automatisch auf den nächsten Werktag "
            "weitergerückt.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: project.shiftDays > 1
                    ? () => store.updateShiftDays(
                          widget.projectId,
                          shiftDays: project.shiftDays - 1,
                        )
                    : null,
              ),
              Text(
                "${project.shiftDays} "
                "${project.shiftDays == 1 ? 'Tag' : 'Tage'}",
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => store.updateShiftDays(
                  widget.projectId,
                  shiftDays: project.shiftDays + 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            "Archivbereich",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            "Ab wie vielen Tagen eine archivierte (bzw. optional auch "
            "erledigte) Aufgabe ganz unten in der Todo-Liste in einen "
            "eingeklappten Archivbereich wandert. 0 = sofort.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: project.archiveAfterDays > 0
                    ? () => store.updateArchiveSettings(
                          widget.projectId,
                          archiveAfterDays: project.archiveAfterDays - 1,
                          moveCompletedToArchiveToo:
                              project.moveCompletedToArchiveToo,
                        )
                    : null,
              ),
              Text(
                "${project.archiveAfterDays} "
                "${project.archiveAfterDays == 1 ? 'Tag' : 'Tage'}",
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => store.updateArchiveSettings(
                  widget.projectId,
                  archiveAfterDays: project.archiveAfterDays + 1,
                  moveCompletedToArchiveToo:
                      project.moveCompletedToArchiveToo,
                ),
              ),
            ],
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "Erledigte nach X Tagen ebenfalls in den Archivbereich "
              "verschieben",
            ),
            value: project.moveCompletedToArchiveToo,
            onChanged: (value) => store.updateArchiveSettings(
              widget.projectId,
              archiveAfterDays: project.archiveAfterDays,
              moveCompletedToArchiveToo: value ?? false,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Endgültiges Löschen",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Archivierte Aufgaben endgültig löschen"),
            subtitle: const Text(
              "Betrifft nur archivierte (nicht erledigte) Aufgaben, "
              "sobald sie im Archivbereich stehen. Kann nicht rückgängig "
              "gemacht werden.",
            ),
            value: project.deleteArchivedTasksPermanently,
            onChanged: (value) => store.updateDeleteArchivedSettings(
              widget.projectId,
              deleteArchivedTasksPermanently: value ?? false,
              deleteArchivedAfterDays: project.deleteArchivedAfterDays,
            ),
          ),
          if (project.deleteArchivedTasksPermanently) ...[
            const SizedBox(height: 4),
            const Text(
              "Zusätzlich zu den Tagen bis zum Archivbereich noch so "
              "viele Tage im Archivbereich behalten, bevor endgültig "
              "gelöscht wird. 0 = sofort.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: project.deleteArchivedAfterDays > 0
                      ? () => store.updateDeleteArchivedSettings(
                            widget.projectId,
                            deleteArchivedTasksPermanently: true,
                            deleteArchivedAfterDays:
                                project.deleteArchivedAfterDays - 1,
                          )
                      : null,
                ),
                Text(
                  "${project.deleteArchivedAfterDays} "
                  "${project.deleteArchivedAfterDays == 1 ? 'Tag' : 'Tage'}",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => store.updateDeleteArchivedSettings(
                    widget.projectId,
                    deleteArchivedTasksPermanently: true,
                    deleteArchivedAfterDays:
                        project.deleteArchivedAfterDays + 1,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 40),
          const Text(
            "Datei-Ablage-Optionen",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Noch keine Optionen für das Datei-Ablage-Modul.",
            style: TextStyle(color: Colors.grey),
          ),
          const Divider(height: 40),
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
