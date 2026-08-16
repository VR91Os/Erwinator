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

  // Frühere Kopien mit anderer Dateiendung (z.B. vorheriges Foto war .png,
  // dieses ist .jpg) erst entfernen, sonst sammeln sich verwaiste Dateien
  // im App-Speicher an, die nie wieder referenziert werden.
  if (await photosDir.exists()) {
    await for (final entity in photosDir.list()) {
      if (entity is! File) continue;
      final base = entity.uri.pathSegments.last;
      if (base.startsWith('$entryId.')) {
        await entity.delete();
      }
    }
  }

  final dot = sourcePath.lastIndexOf('.');
  final ext = dot == -1 ? 'jpg' : sourcePath.substring(dot + 1);
  final destPath = '${photosDir.path}/$entryId.$ext';
  await File(sourcePath).copy(destPath);
  return destPath;
}
