import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audit_entry.dart';
import '../models/gewerk.dart';
import '../models/modules/file_module.dart';
import '../models/modules/todo_module.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../state/project_store.dart';
import '../state/settings_store.dart';
import '../utils/file_export.dart';
import '../utils/file_type_utils.dart';
import '../utils/finance_detection.dart';
import '../utils/id_generator.dart';
import '../utils/image_storage.dart';
import '../utils/large_file_confirm.dart';
import '../utils/project_file_lookup.dart';
import '../utils/safe_notify.dart';
import '../widgets/app_bar.dart';
import '../widgets/dialogs/finance_entry_dialog.dart';
import '../widgets/dialogs/link_file_dialog.dart';
import 'photo_annotation_screen.dart';

const _statusOptions = ['offen', 'teilweise', 'erledigt', 'archiviert'];

String _statusLabel(String status) => switch (status) {
      'offen' => 'Offen',
      'teilweise' => 'Teilweise erledigt',
      'erledigt' => 'Erledigt',
      'archiviert' => 'Archiviert',
      _ => status,
    };

class TaskDetailScreen extends StatelessWidget {
  final String projectId;
  final String gewerkId;
  final String moduleId;
  final String taskId;

  const TaskDetailScreen({
    super.key,
    required this.projectId,
    required this.gewerkId,
    required this.moduleId,
    required this.taskId,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProjectStore>();
    final actor = context.watch<SettingsStore>().currentUserKurzzeichen;

    Project? project;
    for (final p in store.projects) {
      if (p.id == projectId) project = p;
    }
    Gewerk? gewerk;
    if (project != null) {
      for (final g in project.gewerke) {
        if (g.id == gewerkId) gewerk = g;
      }
    }
    TodoModule? module;
    if (gewerk != null) {
      for (final m in gewerk.modules) {
        if (m.id == moduleId && m is TodoModule) module = m;
      }
    }
    Task? task;
    if (module != null) {
      for (final t in module.tasks) {
        if (t.id == taskId) task = t;
      }
    }

    if (project == null || gewerk == null || module == null || task == null) {
      // Aufgabe/Gewerk/Modul wurde inzwischen gelöscht (z.B. durch Sync von
      // einem anderen Gerät, während dieser Screen offen war) -> statt
      // abzustürzen einfach zurück.
      return Scaffold(
        appBar: buildAppBar("Aufgabe", context, true),
        body: const Center(child: Text("Diese Aufgabe existiert nicht mehr.")),
      );
    }

    final resolvedProject = project;
    final resolvedGewerk = gewerk;
    final resolvedTask = task;

    final linkedFiles = resolvedTask.itemRefs
        .map((id) => findFileEntry(resolvedProject, id))
        .whereType<FileLocation>()
        .toList();
    final documents =
        linkedFiles.where((f) => f.entry.fileType != 'photo').toList();
    final photos =
        linkedFiles.where((f) => f.entry.fileType == 'photo').toList();

    return Scaffold(
      appBar: buildAppBar("Aufgabe", context, true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  resolvedTask.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: "Umbenennen",
                onPressed: () => _showRenameDialog(context, resolvedTask),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: resolvedTask.status,
            decoration: const InputDecoration(labelText: "Status"),
            items: _statusOptions
                .map((s) =>
                    DropdownMenuItem(value: s, child: Text(_statusLabel(s))))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              context.read<ProjectStore>().setTaskStatusDirect(
                  projectId, gewerkId, moduleId, resolvedTask.id,
                  status: value, actor: actor);
            },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Hohe Priorität"),
            value: resolvedTask.isHighPriority,
            onChanged: (value) => context.read<ProjectStore>().setTaskHighPriority(
                projectId, gewerkId, moduleId, resolvedTask.id,
                isHighPriority: value ?? false, actor: actor),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  resolvedTask.dueDate == null
                      ? "Kein Fälligkeitsdatum"
                      : "Fällig: ${resolvedTask.dueDate!.day}.${resolvedTask.dueDate!.month}.${resolvedTask.dueDate!.year}",
                ),
              ),
              if (resolvedTask.dueDate != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: "Fälligkeit entfernen",
                  onPressed: () => context.read<ProjectStore>().setTaskDueDate(
                      projectId, gewerkId, moduleId, resolvedTask.id,
                      dueDate: null, actor: actor),
                ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: resolvedTask.dueDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null || !context.mounted) return;
                  context.read<ProjectStore>().setTaskDueDate(
                      projectId, gewerkId, moduleId, resolvedTask.id,
                      dueDate: picked, actor: actor);
                },
                child: const Text("Datum wählen"),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              const Expanded(
                child: Text("Beschreibung",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: "Beschreibung bearbeiten",
                onPressed: () =>
                    _showEditDescriptionDialog(context, resolvedTask),
              ),
            ],
          ),
          Text(
            resolvedTask.description.isEmpty
                ? "Keine Beschreibung"
                : resolvedTask.description,
            style: resolvedTask.description.isEmpty
                ? const TextStyle(color: Colors.grey)
                : null,
          ),
          const Divider(height: 32),
          const Text("Dokumente", style: TextStyle(fontWeight: FontWeight.bold)),
          if (documents.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text("Keine Dokumente verknüpft",
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ...documents.map((loc) => _linkedFileTile(context, resolvedTask, loc)),
          const SizedBox(height: 8),
          const Text("Fotos", style: TextStyle(fontWeight: FontWeight.bold)),
          if (photos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text("Keine Fotos verknüpft",
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ...photos.map((loc) => _linkedFileTile(context, resolvedTask, loc)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => showLinkFileDialog(
                  context,
                  project: resolvedProject,
                  onPicked: (fileEntryId) => context
                      .read<ProjectStore>()
                      .addTaskItemRef(projectId, gewerkId, moduleId,
                          resolvedTask.id, fileEntryId,
                          actor: actor),
                ),
                icon: const Icon(Icons.link),
                label: const Text("Vorhandene Datei verknüpfen"),
              ),
              OutlinedButton.icon(
                onPressed: () => _uploadNewFile(
                    context, resolvedProject, resolvedGewerk, resolvedTask, actor),
                icon: const Icon(Icons.upload_file),
                label: const Text("Neue Datei hochladen"),
              ),
            ],
          ),
          if (resolvedTask.history.isNotEmpty) ...[
            const Divider(height: 32),
            const Text("Verlauf", style: TextStyle(fontWeight: FontWeight.bold)),
            ...([...resolvedTask.history]
                  ..sort((a, b) => b.timestamp.compareTo(a.timestamp)))
                .map((h) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "${h.timestamp.day}.${h.timestamp.month}.${h.timestamp.year} "
                        "${h.timestamp.hour.toString().padLeft(2, '0')}:"
                        "${h.timestamp.minute.toString().padLeft(2, '0')} · "
                        "${h.kurzzeichen}: ${h.action}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )),
          ],
        ],
      ),
    );
  }

  Widget _linkedFileTile(BuildContext context, Task task, FileLocation loc) {
    final actor = context.read<SettingsStore>().currentUserKurzzeichen;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(fileTypeIcon(loc.entry.fileType)),
      title: Text(loc.entry.name),
      subtitle: Text(loc.gewerk.name),
      onTap: () => loc.entry.fileType == 'photo'
          ? _openPhoto(context, loc)
          : _downloadFile(context, loc),
      trailing: IconButton(
        icon: const Icon(Icons.link_off, size: 18),
        tooltip: "Verknüpfung entfernen",
        onPressed: () => context.read<ProjectStore>().removeTaskItemRef(
            projectId, gewerkId, moduleId, task.id, loc.entry.id,
            actor: actor),
      ),
    );
  }

  Future<void> _downloadFile(BuildContext context, FileLocation loc) async {
    final ok = await downloadFileEntryContent(loc.entry);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Für diese Datei ist kein Inhalt gespeichert (z.B. vor "
            "diesem Update hochgeladen).",
          ),
        ),
      );
    }
  }

  void _openPhoto(BuildContext context, FileLocation loc) {
    if (loc.entry.localImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Foto-Bearbeitung ist auf dieser Plattform nicht verfügbar "
            "(nur Android/iOS/Desktop) oder für dieses Foto nicht "
            "gespeichert.",
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoAnnotationScreen(
          projectId: projectId,
          gewerkId: loc.gewerk.id,
          moduleId: loc.module.id,
          entryId: loc.entry.id,
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Task task) {
    final controller = TextEditingController(text: task.name);
    final actor = context.read<SettingsStore>().currentUserKurzzeichen;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Aufgabe umbenennen"),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                final store = context.read<ProjectStore>();
                final name = controller.text;
                popDialogThen(
                  dialogContext,
                  () => store.renameTask(
                      projectId, gewerkId, moduleId, task.id,
                      name: name, actor: actor),
                );
              },
              child: const Text("Speichern"),
            ),
          ],
        );
      },
    ).then((_) => controller.dispose());
  }

  void _showEditDescriptionDialog(BuildContext context, Task task) {
    final controller = TextEditingController(text: task.description);
    final actor = context.read<SettingsStore>().currentUserKurzzeichen;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Beschreibung bearbeiten"),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                final store = context.read<ProjectStore>();
                final description = controller.text;
                popDialogThen(
                  dialogContext,
                  () => store.updateTaskDescription(
                      projectId, gewerkId, moduleId, task.id,
                      description: description, actor: actor),
                );
              },
              child: const Text("Speichern"),
            ),
          ],
        );
      },
    ).then((_) => controller.dispose());
  }

  // Lädt eine neue Datei direkt aus der Aufgabe hoch: landet automatisch im
  // File-Modul des Gewerk-Reiters dieser Aufgabe (wird angelegt, falls noch
  // keins existiert) und wird sofort mit der Aufgabe verknüpft - keine
  // doppelte Ablage, die Datei liegt genau einmal in der File-Ablage.
  Future<void> _uploadNewFile(
    BuildContext context,
    Project project,
    Gewerk gewerk,
    Task task,
    String actor,
  ) async {
    final store = context.read<ProjectStore>();
    final PickedFileInfo? picked;
    try {
      picked = await pickFileInfo();
    } on FileTooLargeException catch (e) {
      if (!context.mounted) return;
      showFileTooLargeSnackBar(context, e.sizeBytes, maxPickableFileSizeBytes);
      return;
    }
    if (picked == null || !context.mounted) return;

    final bytes = picked.bytes;
    if (bytes != null && !await confirmLargeFile(context, bytes.length)) {
      return;
    }
    if (!context.mounted) return;

    String? fileModuleId;
    for (final m in gewerk.modules) {
      if (m is FileModule) fileModuleId = m.id;
    }
    fileModuleId ??=
        await store.addModule(projectId, gewerkId, FileModule.moduleType);
    if (fileModuleId == null || !context.mounted) return;

    final extension = fileExtensionOf(picked.name);
    final fileType = detectFileType(extension);
    final id = newId();

    String? localImagePath;
    if (fileType == 'photo' && !kIsWeb && picked.path != null) {
      try {
        localImagePath = await copyImageToLocalStorage(picked.path!, id);
      } catch (_) {
        localImagePath = null;
      }
    }
    if (!context.mounted) return;

    final entry = FileEntry(
      id: id,
      name: fileNameWithoutExtension(picked.name),
      fileType: fileType,
      versions: [
        FileVersion(
          id: newId(),
          label: "1.0",
          createdBy: actor,
          content: bytes == null ? '' : base64Encode(bytes),
          extension: extension,
        ),
      ],
      history: [AuditEntry(kurzzeichen: actor, action: 'hochgeladen')],
      localImagePath: localImagePath,
    );
    await store.addFileEntry(projectId, gewerkId, fileModuleId, entry);
    await store.addTaskItemRef(projectId, gewerkId, moduleId, task.id, id,
        actor: actor);

    if (fileType == 'pdf' && bytes != null && project.financeEnabled) {
      final detected = await detectFinanceInfo(bytes);
      if (!context.mounted) return;
      if (!detected.isEmpty) {
        showFinanceEntryDialog(
          context,
          projectId: projectId,
          gewerke: project.gewerke,
          initialGewerkId: gewerkId,
          fileModuleId: fileModuleId,
          fileEntryId: id,
          detected: detected,
        );
      }
    }
  }
}
