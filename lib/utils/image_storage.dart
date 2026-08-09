import 'dart:io';

import 'package:path_provider/path_provider.dart';

// Kopiert ein ausgewähltes Foto dauerhaft in den App-eigenen Speicher,
// damit es auch nach Neustart für die Foto-Bearbeitung verfügbar bleibt
// (der vom System-Dateidialog gelieferte Pfad ist nicht garantiert
// dauerhaft gültig). Nur auf nativen Plattformen aufrufbar – im Web gibt
// es kein Dateisystem dafür.
Future<String> copyImageToLocalStorage(String sourcePath, String entryId) async {
  final dir = await getApplicationDocumentsDirectory();
  final photosDir = Directory('${dir.path}/baustelli_photos');
  if (!await photosDir.exists()) {
    await photosDir.create(recursive: true);
  }
  final dot = sourcePath.lastIndexOf('.');
  final ext = dot == -1 ? 'jpg' : sourcePath.substring(dot + 1);
  final destPath = '${photosDir.path}/$entryId.$ext';
  await File(sourcePath).copy(destPath);
  return destPath;
}
