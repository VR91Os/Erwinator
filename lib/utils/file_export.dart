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
