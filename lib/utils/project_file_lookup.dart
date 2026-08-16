import '../models/gewerk.dart';
import '../models/modules/file_module.dart';
import '../models/project.dart';

// Ort eines Datei-Eintrags innerhalb des Projekts (Gewerk + Modul stehen
// nicht auf FileEntry selbst, werden aber für Navigation/Anzeige gebraucht,
// z.B. um von einer per Task.itemRefs verknüpften Datei zur richtigen
// PhotoAnnotationScreen zu springen).
class FileLocation {
  final Gewerk gewerk;
  final FileModule module;
  final FileEntry entry;

  const FileLocation(this.gewerk, this.module, this.entry);
}

// Sucht projektweit über alle Gewerke/File-Module (nicht nur ein einzelnes),
// da eine Aufgabe eine Datei aus jedem beliebigen Gewerk referenzieren kann.
FileLocation? findFileEntry(Project project, String fileEntryId) {
  for (final gewerk in project.gewerke) {
    for (final module in gewerk.modules.whereType<FileModule>()) {
      for (final entry in module.entries) {
        if (entry.id == fileEntryId) return FileLocation(gewerk, module, entry);
      }
    }
  }
  return null;
}

// Alle Datei-Einträge im Projekt, für die Verknüpfen-Auswahl (projektweite
// Suche, siehe findFileEntry).
List<FileLocation> allFileEntries(Project project) {
  final result = <FileLocation>[];
  for (final gewerk in project.gewerke) {
    for (final module in gewerk.modules.whereType<FileModule>()) {
      for (final entry in module.entries) {
        result.add(FileLocation(gewerk, module, entry));
      }
    }
  }
  return result;
}
