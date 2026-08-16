import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/modules/file_module.dart';

// Speichert Text als Datei: im Browser als Download, auf Desktop über den
// System-Speichern-Dialog.
Future<void> exportTextFile({
  required String fileName,
  required String content,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  if (kIsWeb) {
    await FilePicker.saveFile(fileName: fileName, bytes: bytes);
    return;
  }
  final path = await FilePicker.saveFile(fileName: fileName);
  if (path == null) return;
  await io.File(path).writeAsBytes(bytes);
}

// Liest eine vom Nutzer ausgewählte Textdatei ein (z.B. für den
// Projekt-Import). Gibt null zurück, wenn abgebrochen wurde.
Future<String?> importTextFile({
  List<String> allowedExtensions = const ['json'],
}) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    withData: kIsWeb,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  if (file.bytes != null) {
    return utf8.decode(file.bytes!);
  }
  if (file.path != null) {
    return io.File(file.path!).readAsString();
  }
  return null;
}

// Name, (nur nativ) lokaler Pfad und Inhalt einer ausgewählten Datei. Im
// Web ist path immer null, da dort kein Dateisystempfad existiert.
class PickedFileInfo {
  final String name;
  final String? path;
  final Uint8List? bytes;
  PickedFileInfo({required this.name, this.path, this.bytes});
}

// Harte Obergrenze für ausgewählte Dateien, unabhängig von der separaten
// Warnung ab 15 MB in file_module_widget.dart (_confirmLargeFile) -
// verhindert, dass eine versehentlich riesige Datei (mehrere hundert MB)
// komplett in den Speicher geladen wird, bevor überhaupt eine Warnung
// angezeigt werden könnte.
const int maxPickableFileSizeBytes = 200 * 1024 * 1024;

class FileTooLargeException implements Exception {
  final int sizeBytes;
  FileTooLargeException(this.sizeBytes);
}

// Öffnet den System-Dateiauswahl-Dialog für die File-Ablage. Liest den
// Inhalt mit ein, damit die Datei in der Projekt-Ablage gespeichert und
// später von jedem Projekt-Mitglied wieder abgerufen werden kann - nicht
// nur Metadaten wie Name/Version. Gibt null zurück, wenn abgebrochen wurde.
// Wirft [FileTooLargeException], wenn die Datei die Obergrenze überschreitet.
Future<PickedFileInfo?> pickFileInfo() async {
  if (kIsWeb) {
    // Web hat keinen Dateisystempfad - der Inhalt muss direkt beim Picken
    // gelesen werden, ein zweistufiges Vorgehen wie unten würde eine zweite
    // Dateiauswahl erfordern.
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.size > maxPickableFileSizeBytes) {
      throw FileTooLargeException(file.size);
    }
    return PickedFileInfo(name: file.name, path: file.path, bytes: file.bytes);
  }

  // Nativ: erst nur Metadaten (inkl. Größe) lesen, bevor der komplette
  // Dateiinhalt in den Speicher geladen wird - vermeidet ein OOM-Risiko bei
  // versehentlich riesigen Dateien auf schwächeren Mobilgeräten.
  final result = await FilePicker.pickFiles();
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  if (file.size > maxPickableFileSizeBytes) {
    throw FileTooLargeException(file.size);
  }
  final bytes =
      file.path == null ? null : await io.File(file.path!).readAsBytes();
  return PickedFileInfo(name: file.name, path: file.path, bytes: bytes);
}

// Speichert Binärdaten als Datei: im Browser als Download, auf
// Desktop/Mobile über den System-Speichern-Dialog. Für den Rückweg aus der
// File-Ablage (Datei wieder abrufen).
Future<void> exportBinaryFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  if (kIsWeb) {
    await FilePicker.saveFile(fileName: fileName, bytes: bytes);
    return;
  }
  final path = await FilePicker.saveFile(fileName: fileName);
  if (path == null) return;
  await io.File(path).writeAsBytes(bytes);
}

// Speichert eine einzelne Version einer File-Ablage-Datei wieder auf dem
// Gerät (Download/Speichern-unter). Jede Version trägt ihren eigenen
// Inhalt, damit auch ältere Versionen nach einem "Neue Version"-Upload
// nicht aus dem Ordner fallen, sondern einzeln abrufbar bleiben. Gibt
// false zurück, wenn für diese Version kein Inhalt hinterlegt ist – z.B.
// bei Versionen von vor dieser Speicherung –, damit der Aufrufer einen
// passenden Hinweis anzeigen kann.
Future<bool> downloadFileVersionContent(
    FileEntry entry, FileVersion version) async {
  if (version.content.isEmpty) return false;
  final bytes = base64Decode(version.content);
  final fileName = version.extension.isEmpty
      ? '${entry.name} (${version.label})'
      : '${entry.name} (${version.label}).${version.extension}';
  await exportBinaryFile(fileName: fileName, bytes: bytes);
  return true;
}

// Kurzform für die neueste Version eines Eintrags.
Future<bool> downloadFileEntryContent(FileEntry entry) async {
  final latest = entry.latestVersion;
  if (latest == null) return false;
  return downloadFileVersionContent(entry, latest);
}
