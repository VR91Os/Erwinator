import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/audit_entry.dart';
import '../../models/modules/file_module.dart';
import '../../screens/photo_annotation_screen.dart';
import '../../state/project_store.dart';
import '../../state/settings_store.dart';
import '../../utils/file_export.dart';
import '../../utils/id_generator.dart';
import '../../utils/image_storage.dart';
import '../audit_info_icon.dart';
import 'module_card.dart';

const _photoExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'};
const _videoExtensions = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'};

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

  String _typeLabel(String fileType) {
    switch (fileType) {
      case 'pdf':
        return 'PDF';
      case 'photo':
        return 'Foto';
      case 'video':
        return 'Video';
      default:
        return 'Dokument';
    }
  }

  // Erkennt den Dateityp automatisch anhand der Dateiendung.
  String _detectFileType(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
    if (ext == 'pdf') return 'pdf';
    if (_photoExtensions.contains(ext)) return 'photo';
    if (_videoExtensions.contains(ext)) return 'video';
    return 'document';
  }

  String _nameWithoutExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? fileName : fileName.substring(0, dot);
  }

  // Versionen sind strikt durchnummeriert (1.0, 1.1, 1.2, …), damit auf
  // einen Blick klar ist, welche die neueste ist.
  String _nextVersionLabel(FileEntry entry) => '1.${entry.versions.length}';

  List<Widget> _versionRows(FileEntry entry) {
    if (entry.versions.length < 2) return const [];
    final sorted = [...entry.versions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.generate(sorted.length, (i) {
      final version = sorted[i];
      final isLatest = i == 0;
      return Padding(
        padding: const EdgeInsets.only(left: 24, top: 2),
        child: Text(
          "Version ${version.label}",
          style: TextStyle(
            fontSize: isLatest ? 13 : 11,
            color: isLatest ? Colors.black87 : Colors.grey,
            fontWeight: isLatest ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      projectId: projectId,
      gewerkId: gewerkId,
      moduleId: module.id,
      icon: "📁",
      defaultTitle: "File-Ablage",
      label: module.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...module.entries.map((entry) {
            final isPhoto = entry.fileType == 'photo';
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_iconFor(entry.fileType), size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "${entry.name} (${entry.versions.length} Version"
                        "${entry.versions.length == 1 ? '' : 'en'})"
                        "${isPhoto && entry.annotations.isNotEmpty ? ' · ${entry.annotations.length} Markierung${entry.annotations.length == 1 ? '' : 'en'}' : ''}",
                      ),
                    ),
                    AuditInfoIcon(history: entry.history),
                    IconButton(
                      icon: const Icon(Icons.add_box_outlined, size: 18),
                      tooltip: "Neue Version",
                      onPressed: () => _showNewVersionDialog(context, entry),
                    ),
                  ],
                ),
                ..._versionRows(entry),
              ],
            );
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: isPhoto
                  ? InkWell(
                      onTap: () => _openPhoto(context, entry),
                      child: content,
                    )
                  : content,
            );
          }),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => _pickAndAddFile(context),
            icon: const Icon(Icons.attach_file),
            label: const Text("Datei auswählen"),
          ),
        ],
      ),
    );
  }

  // Öffnet die Systemauswahl, erkennt Typ + Name automatisch. Gibt es
  // bereits Einträge desselben Typs (z.B. PDF und PDF), wird direkt deren
  // Liste angeboten (Klick = neue Version). Sonst – oder bei "Neue Datei"
  // aus dieser Liste – wird nach einem Namen gefragt; überspringen
  // übernimmt den tatsächlichen Dateinamen. Fotos werden zusätzlich (nur
  // nativ) lokal kopiert, damit die Foto-Bearbeitung funktioniert.
  Future<void> _pickAndAddFile(BuildContext context) async {
    final picked = await pickFileInfo();
    if (picked == null || !context.mounted) return;

    final fileType = _detectFileType(picked.name);
    final suggestedName = _nameWithoutExtension(picked.name);

    final existingOfType =
        module.entries.where((e) => e.fileType == fileType).toList();
    if (existingOfType.isNotEmpty) {
      _showExistingTypeDialog(
          context, existingOfType, suggestedName, fileType, picked.path);
      return;
    }
    _showNameDialog(context, suggestedName, fileType, picked.path);
  }

  Future<void> _addEntry(
    BuildContext context, {
    required String name,
    required String fileType,
    String? sourcePath,
  }) async {
    final store = context.read<ProjectStore>();
    final actor = context.read<SettingsStore>().currentUserKurzzeichen;
    final id = newId();

    String? localImagePath;
    if (fileType == 'photo' && !kIsWeb && sourcePath != null) {
      try {
        localImagePath = await copyImageToLocalStorage(sourcePath, id);
      } catch (_) {
        localImagePath = null;
      }
    }
    if (!context.mounted) return;

    final entry = FileEntry(
      id: id,
      name: name,
      fileType: fileType,
      versions: [FileVersion(id: newId(), label: "1.0", createdBy: actor)],
      history: [AuditEntry(kurzzeichen: actor, action: 'hochgeladen')],
      localImagePath: localImagePath,
    );
    store.addFileEntry(projectId, gewerkId, module.id, entry);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$name" hinzugefügt (${_typeLabel(fileType)})')),
    );
  }

  void _openPhoto(BuildContext context, FileEntry entry) {
    if (entry.localImagePath == null) {
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
          gewerkId: gewerkId,
          moduleId: module.id,
          entryId: entry.id,
        ),
      ),
    );
  }

  void _addVersionTo(BuildContext context, FileEntry entry) {
    final store = context.read<ProjectStore>();
    final actor = context.read<SettingsStore>().currentUserKurzzeichen;
    final label = _nextVersionLabel(entry);
    store.addFileVersion(
      projectId,
      gewerkId,
      module.id,
      entry.id,
      FileVersion(id: newId(), label: label, createdBy: actor),
      actor: actor,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${entry.name}" aktualisiert (Version $label)')),
    );
  }

  void _showExistingTypeDialog(
    BuildContext context,
    List<FileEntry> existingOfType,
    String suggestedName,
    String fileType,
    String? sourcePath,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("${_typeLabel(fileType)} hochladen"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Aktualisiert das eine bestehende Datei vom Typ "
                    "${_typeLabel(fileType)} oder ist es eine neue Datei?",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  ...existingOfType.map((entry) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_iconFor(fileType)),
                      title: Text(entry.name),
                      subtitle: Text(
                        "wird Version ${_nextVersionLabel(entry)}",
                      ),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        _addVersionTo(context, entry);
                      },
                    );
                  }),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text("Neue Datei"),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _showNameDialog(
                          context, suggestedName, fileType, sourcePath);
                    },
                  ),
                ],
              ),
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

  // Fragt nach einem Namen für die Datei; "Überspringen" übernimmt den
  // tatsächlichen Dateinamen unverändert.
  void _showNameDialog(
    BuildContext context,
    String suggestedName,
    String fileType,
    String? sourcePath,
  ) {
    final nameController = TextEditingController(text: suggestedName);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("${_typeLabel(fileType)} benennen"),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Name",
              hintText: "z.B. \"Angebot Meier\"",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _addEntry(
                  context,
                  name: suggestedName,
                  fileType: fileType,
                  sourcePath: sourcePath,
                );
              },
              child: const Text("Überspringen"),
            ),
            ElevatedButton(
              onPressed: () {
                final typed = nameController.text.trim();
                Navigator.pop(dialogContext);
                _addEntry(
                  context,
                  name: typed.isEmpty ? suggestedName : typed,
                  fileType: fileType,
                  sourcePath: sourcePath,
                );
              },
              child: const Text("Speichern"),
            ),
          ],
        );
      },
    );
  }

  void _showNewVersionDialog(BuildContext context, FileEntry entry) {
    final nextLabel = _nextVersionLabel(entry);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Neue Version für ${entry.name}"),
          content: Text("Wird als Version $nextLabel gespeichert."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _addVersionTo(context, entry);
              },
              child: const Text("Hinzufügen"),
            ),
          ],
        );
      },
    );
  }
}
