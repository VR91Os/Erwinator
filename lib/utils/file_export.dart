import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

// Name + (nur nativ) lokaler Pfad einer ausgewählten Datei. Im Web ist
// path immer null, da dort kein Dateisystempfad existiert.
class PickedFileInfo {
  final String name;
  final String? path;
  PickedFileInfo({required this.name, this.path});
}

// Öffnet den System-Dateiauswahl-Dialog für die File-Ablage. Der Inhalt
// wird von der App selbst bewusst nicht dauerhaft gespeichert – sie
// trackt in der Regel nur Metadaten (wer/wann/welche Version), kein
// echtes Datei-Hosting. Ausnahme: Fotos werden nativ lokal kopiert, damit
// die Foto-Bearbeitung (Kommentare/Messungen) funktioniert – dafür wird
// hier zusätzlich der Quellpfad zurückgegeben. Gibt null zurück, wenn
// abgebrochen wurde.
Future<PickedFileInfo?> pickFileInfo() async {
  final result = await FilePicker.pickFiles();
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  return PickedFileInfo(name: file.name, path: file.path);
}
