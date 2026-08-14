import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/audit_entry.dart';
import '../../models/documentation_entry.dart';
import '../../models/modules/file_module.dart';
import '../../screens/photo_annotation_screen.dart';
import '../../state/documentation_store.dart';
import '../../state/project_store.dart';
import '../../state/settings_store.dart';
import '../../utils/file_export.dart';
import '../../utils/id_generator.dart';
import '../../utils/image_storage.dart';
import '../audit_info_icon.dart';
import 'module_card.dart';

const _photoExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'};
const _videoExtensions = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'};

// Ab dieser Größe wird vor dem Speichern gewarnt, da der Dateiinhalt mit
// den Projektdaten synchronisiert wird und große Dateien (v.a. Videos)
// Speicherplatz und Sync-Geschwindigkeit spürbar beeinträchtigen können.
const _largeFileWarningBytes = 15 * 1024 * 1024;

Future<bool> _confirmLargeFile(BuildContext context, int byteSize) async {
  if (byteSize <= _largeFileWarningBytes) return true;
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

  String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  // Erkennt den Dateityp automatisch anhand der Dateiendung.
  String _detectFileType(String extension) {
    if (extension == 'pdf') return 'pdf';
    if (_photoExtensions.contains(extension)) return 'photo';
    if (_videoExtensions.contains(extension)) return 'video';
    return 'document';
  }

  String _nameWithoutExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? fileName : fileName.substring(0, dot);
  }

  // Versionen sind strikt durchnummeriert (1.0, 1.1, 1.2, …), damit auf
  // einen Blick klar ist, welche die neueste ist.
  String _nextVersionLabel(FileEntry entry) => '1.${entry.versions.length}';

  // Jede Version bleibt einzeln abrufbar – auch ältere Versionen fallen
  // nach einem "Neue Version"-Upload nicht aus dem Ordner.
  List<Widget> _versionRows(BuildContext context, FileEntry entry) {
    if (entry.versions.length < 2) return const [];
    final sorted = [...entry.versions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.generate(sorted.length, (i) {
      final version = sorted[i];
      final isLatest = i == 0;
      return Padding(
        padding: const EdgeInsets.only(left: 24, top: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "Version ${version.label}",
                style: TextStyle(
                  fontSize: isLatest ? 13 : 11,
                  color: isLatest ? Colors.black87 : Colors.grey,
                  fontWeight: isLatest ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 15,
                icon: const Icon(Icons.download_outlined),
                tooltip: "Diese Version abrufen",
                onPressed: () => _downloadVersion(context, entry, version),
              ),
            ),
          ],
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
                      icon: const Icon(Icons.download_outlined, size: 18),
                      tooltip: "Datei abrufen",
                      onPressed: () => _downloadEntry(context, entry),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_box_outlined, size: 18),
                      tooltip: "Neue Version",
                      onPressed: () => _showNewVersionDialog(context, entry),
                    ),
                  ],
                ),
                ..._versionRows(context, entry),
              ],
            );
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              // Name antippen öffnet die Datei: bei Fotos die Bearbeitung,
              // sonst dasselbe Abrufen wie über den Download-Button.
              child: InkWell(
                onTap: () => isPhoto
                    ? _openPhoto(context, entry)
                    : _downloadEntry(context, entry),
                child: content,
              ),
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
  // nativ) lokal kopiert, damit die Foto-Bearbeitung funktioniert. Der
  // Inhalt (bytes) wird immer mitgespeichert, damit die Datei später
  // wieder abrufbar ist.
  Future<void> _pickAndAddFile(BuildContext context) async {
    final picked = await pickFileInfo();
    if (picked == null || !context.mounted) return;

    final extension = _extensionOf(picked.name);
    final fileType = _detectFileType(extension);
    final suggestedName = _nameWithoutExtension(picked.name);

    final existingOfType =
        module.entries.where((e) => e.fileType == fileType).toList();
    if (existingOfType.isNotEmpty) {
      _showExistingTypeDialog(context, existingOfType, suggestedName,
          fileType, extension, picked.path, picked.bytes);
      return;
    }
    _showNameDialog(
        context, suggestedName, fileType, extension, picked.path, picked.bytes);
  }

  Future<void> _addEntry(
    BuildContext context, {
    required String name,
    required String fileType,
    String extension = '',
    String? sourcePath,
    Uint8List? bytes,
    bool saveToDocumentation = false,
  }) async {
    if (bytes != null && !await _confirmLargeFile(context, bytes.length)) {
      return;
    }
    if (!context.mounted) return;
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
    store.addFileEntry(projectId, gewerkId, module.id, entry);

    if (saveToDocumentation && bytes != null) {
      final project = store.projects.firstWhere((p) => p.id == projectId);
      final gewerk = project.gewerke.firstWhere((g) => g.id == gewerkId);
      context.read<DocumentationStore>().addEntry(
            DocumentationEntry(
              id: newId(),
              name: name,
              fileType: fileType,
              content: base64Encode(bytes),
              extension: extension,
              createdBy: actor,
              projectName: project.name,
              gewerkName: gewerk.name,
            ),
          );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$name" hinzugefügt (${_typeLabel(fileType)})')),
    );
  }

  Future<void> _downloadEntry(BuildContext context, FileEntry entry) async {
    final ok = await downloadFileEntryContent(entry);
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

  Future<void> _downloadVersion(
      BuildContext context, FileEntry entry, FileVersion version) async {
    final ok = await downloadFileVersionContent(entry, version);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Für diese Version ist kein Inhalt gespeichert (z.B. vor "
            "diesem Update hochgeladen).",
          ),
        ),
      );
    }
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

  Future<void> _addVersionTo(
    BuildContext context,
    FileEntry entry, {
    String extension = '',
    String? sourcePath,
    Uint8List? bytes,
  }) async {
    if (bytes != null && !await _confirmLargeFile(context, bytes.length)) {
      return;
    }
    if (!context.mounted) return;
    final store = context.read<ProjectStore>();
    final actor = context.read<SettingsStore>().currentUserKurzzeichen;
    final label = _nextVersionLabel(entry);

    if (entry.fileType == 'photo' && !kIsWeb && sourcePath != null) {
      try {
        entry.localImagePath =
            await copyImageToLocalStorage(sourcePath, entry.id);
      } catch (_) {
        // Bisherigen lokalen Pfad behalten, falls das Kopieren fehlschlägt.
      }
    }
    if (!context.mounted) return;

    store.addFileVersion(
      projectId,
      gewerkId,
      module.id,
      entry.id,
      FileVersion(
        id: newId(),
        label: label,
        createdBy: actor,
        content: bytes == null ? '' : base64Encode(bytes),
        extension: extension,
      ),
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
    String extension,
    String? sourcePath,
    Uint8List? bytes,
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
                        _addVersionTo(
                          context,
                          entry,
                          extension: extension,
                          sourcePath: sourcePath,
                          bytes: bytes,
                        );
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
                      _showNameDialog(context, suggestedName, fileType,
                          extension, sourcePath, bytes);
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
    String extension,
    String? sourcePath,
    Uint8List? bytes,
  ) {
    final nameController = TextEditingController(text: suggestedName);
    final offerDocumentation = fileType == 'photo' || fileType == 'video';
    bool saveToDocumentation = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text("${_typeLabel(fileType)} benennen"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: "Name",
                      hintText: "z.B. \"Angebot Meier\"",
                    ),
                  ),
                  if (offerDocumentation)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: saveToDocumentation,
                      onChanged: (value) => setDialogState(
                          () => saveToDocumentation = value ?? false),
                      title: const Text(
                        "Für Dokumentation in eigenen Ordner sichern?",
                      ),
                      subtitle: const Text(
                        "Bleibt projektübergreifend erhalten, z.B. für "
                        "Maße, die man später wieder braucht.",
                      ),
                    ),
                ],
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
                      extension: extension,
                      sourcePath: sourcePath,
                      bytes: bytes,
                      saveToDocumentation: saveToDocumentation,
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
                      extension: extension,
                      sourcePath: sourcePath,
                      bytes: bytes,
                      saveToDocumentation: saveToDocumentation,
                    );
                  },
                  child: const Text("Speichern"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Wählt die aktualisierte Datei aus, bevor die neue Version bestätigt
  // wird – ohne das würde der Dateiinhalt der neuen Version nie
  // gespeichert.
  Future<void> _showNewVersionDialog(
      BuildContext context, FileEntry entry) async {
    final picked = await pickFileInfo();
    if (picked == null || !context.mounted) return;

    final extension = _extensionOf(picked.name);
    final nextLabel = _nextVersionLabel(entry);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Neue Version für ${entry.name}"),
          content: Text(
            "\"${picked.name}\" wird als Version $nextLabel gespeichert.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _addVersionTo(
                  context,
                  entry,
                  extension: extension,
                  sourcePath: picked.path,
                  bytes: picked.bytes,
                );
              },
              child: const Text("Hinzufügen"),
            ),
          ],
        );
      },
    );
  }
}
