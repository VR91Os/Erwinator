import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/audit_entry.dart';
import '../../models/documentation_entry.dart';
import '../../models/finance_entry.dart';
import '../../models/modules/file_module.dart';
import '../../models/project.dart';
import '../../screens/photo_annotation_screen.dart';
import '../../state/documentation_store.dart';
import '../../state/project_store.dart';
import '../../state/settings_store.dart';
import '../../utils/file_export.dart';
import '../../utils/file_type_utils.dart';
import '../../utils/finance_detection.dart';
import '../../utils/id_generator.dart';
import '../../utils/image_storage.dart';
import '../../utils/large_file_confirm.dart';
import '../audit_info_icon.dart';
import '../dialogs/finance_entry_dialog.dart';
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
    final store = context.watch<ProjectStore>();
    final project = store.projects.firstWhere((p) => p.id == projectId);

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
            final isPdf = entry.fileType == 'pdf';
            final linkedFinanceEntry =
                isPdf ? _existingFinanceEntryFor(project, entry.id) : null;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(fileTypeIcon(entry.fileType), size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "${entry.name} (${entry.versions.length} Version"
                        "${entry.versions.length == 1 ? '' : 'en'})"
                        "${isPhoto && entry.annotations.isNotEmpty ? ' · ${entry.annotations.length} Markierung${entry.annotations.length == 1 ? '' : 'en'}' : ''}",
                      ),
                    ),
                    AuditInfoIcon(history: entry.history),
                    if (isPdf && project.financeEnabled)
                      IconButton(
                        icon: Icon(
                          linkedFinanceEntry == null
                              ? Icons.euro_symbol_outlined
                              : Icons.euro_symbol,
                          size: 18,
                          color: linkedFinanceEntry == null
                              ? null
                              : Colors.green.shade700,
                        ),
                        tooltip: linkedFinanceEntry == null
                            ? "Als Angebot/Rechnung erfassen"
                            : "Angebot/Rechnung bearbeiten",
                        onPressed: () =>
                            _showFinanceEntryForFile(context, entry),
                      ),
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
    final PickedFileInfo? picked;
    try {
      picked = await pickFileInfo();
    } on FileTooLargeException catch (e) {
      if (!context.mounted) return;
      showFileTooLargeSnackBar(context, e.sizeBytes, maxPickableFileSizeBytes);
      return;
    }
    if (picked == null || !context.mounted) return;
    final resolvedPicked = picked;

    final extension = fileExtensionOf(resolvedPicked.name);
    final fileType = detectFileType(extension);
    final suggestedName = fileNameWithoutExtension(resolvedPicked.name);

    final existingOfType =
        module.entries.where((e) => e.fileType == fileType).toList();
    if (existingOfType.isNotEmpty) {
      _showExistingTypeDialog(context, existingOfType, suggestedName,
          fileType, extension, resolvedPicked.path, resolvedPicked.bytes);
      return;
    }
    _showNameDialog(context, suggestedName, fileType, extension,
        resolvedPicked.path, resolvedPicked.bytes);
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
    if (bytes != null && !await confirmLargeFile(context, bytes.length)) {
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
      SnackBar(content: Text('"$name" hinzugefügt (${fileTypeLabel(fileType)})')),
    );

    if (fileType == 'pdf' && bytes != null) {
      await _detectAndPromptFinanceEntry(context, fileEntryId: id, bytes: bytes);
    }
  }

  // Läuft nach dem Speichern eines PDFs (neue Datei oder neue Version),
  // wenn das Finanzen-Modul aktiviert ist: liest den Text aus, versucht
  // Typ/Betrag zu erkennen und öffnet - nur bei einem plausiblen Treffer,
  // sonst bleibt der Upload einfach unauffällig - den ohnehin vorhandenen
  // Erfassen-Dialog vorbefüllt. Speichert nie automatisch ohne Bestätigung.
  Future<void> _detectAndPromptFinanceEntry(
    BuildContext context, {
    required String fileEntryId,
    required Uint8List bytes,
    FinanceEntry? existing,
  }) async {
    final store = context.read<ProjectStore>();
    final project = store.projects.firstWhere((p) => p.id == projectId);
    if (!project.financeEnabled) return;

    final detected = await detectFinanceInfo(bytes);
    if (!context.mounted) return;
    if (detected.isEmpty && existing == null) return;

    showFinanceEntryDialog(
      context,
      projectId: projectId,
      gewerke: project.gewerke,
      initialGewerkId: gewerkId,
      fileModuleId: module.id,
      fileEntryId: fileEntryId,
      existing: existing,
      detected: detected.isEmpty ? null : detected,
    );
  }

  FinanceEntry? _existingFinanceEntryFor(Project project, String fileEntryId) {
    for (final e in project.financeEntries) {
      if (e.fileEntryId == fileEntryId) return e;
    }
    return null;
  }

  // Manueller Aufruf über den Button an einem PDF-Eintrag: liest die
  // gespeicherte neueste Version erneut ein (funktioniert auch für Dateien,
  // die hochgeladen wurden, bevor das Finanzen-Modul aktiviert war) und
  // öffnet den Erfassen-/Bearbeiten-Dialog, vorbefüllt mit einem eventuell
  // bereits bestehenden Eintrag.
  Future<void> _showFinanceEntryForFile(
      BuildContext context, FileEntry entry) async {
    final store = context.read<ProjectStore>();
    final project = store.projects.firstWhere((p) => p.id == projectId);
    final existing = _existingFinanceEntryFor(project, entry.id);
    final latest = entry.latestVersion;

    FinanceDetectionResult? detected;
    if (latest != null && latest.content.isNotEmpty) {
      try {
        detected = await detectFinanceInfo(base64Decode(latest.content));
      } catch (_) {
        detected = null;
      }
    }
    if (!context.mounted) return;

    showFinanceEntryDialog(
      context,
      projectId: projectId,
      gewerke: project.gewerke,
      initialGewerkId: gewerkId,
      fileModuleId: module.id,
      fileEntryId: entry.id,
      existing: existing,
      detected: (detected == null || detected.isEmpty) ? null : detected,
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
    if (bytes != null && !await confirmLargeFile(context, bytes.length)) {
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

    if (entry.fileType == 'pdf' && bytes != null) {
      final existing = _existingFinanceEntryFor(
        store.projects.firstWhere((p) => p.id == projectId),
        entry.id,
      );
      await _detectAndPromptFinanceEntry(
        context,
        fileEntryId: entry.id,
        bytes: bytes,
        existing: existing,
      );
    }
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
          title: Text("${fileTypeLabel(fileType)} hochladen"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Aktualisiert das eine bestehende Datei vom Typ "
                    "${fileTypeLabel(fileType)} oder ist es eine neue Datei?",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  ...existingOfType.map((entry) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(fileTypeIcon(fileType)),
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
              title: Text("${fileTypeLabel(fileType)} benennen"),
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
    final PickedFileInfo? picked;
    try {
      picked = await pickFileInfo();
    } on FileTooLargeException catch (e) {
      if (!context.mounted) return;
      showFileTooLargeSnackBar(context, e.sizeBytes, maxPickableFileSizeBytes);
      return;
    }
    if (picked == null || !context.mounted) return;
    final resolvedPicked = picked;

    final extension = fileExtensionOf(resolvedPicked.name);
    final nextLabel = _nextVersionLabel(entry);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Neue Version für ${entry.name}"),
          content: Text(
            "\"${resolvedPicked.name}\" wird als Version $nextLabel gespeichert.",
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
                  sourcePath: resolvedPicked.path,
                  bytes: resolvedPicked.bytes,
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
