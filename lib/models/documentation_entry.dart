// Ein Foto/Video, das beim Hochladen bewusst zusätzlich in den
// projektübergreifenden Dokumentations-Ordner gesichert wurde (Checkbox
// "Für Dokumentation in eigenen Ordner sichern?"). Unabhängig vom
// ursprünglichen Projekt/Gewerk gespeichert, damit es auch erhalten
// bleibt, wenn das Projekt später gelöscht wird – z.B. Maße von
// Leerschläuchen, die auch nach der Bauphase noch gebraucht werden.
class DocumentationEntry {
  String id;
  String name;
  // 'photo' | 'video'
  String fileType;
  // Base64-kodierter Dateiinhalt.
  String content;
  // Ursprüngliche Dateiendung ohne Punkt (z.B. "jpg", "mp4").
  String extension;
  String createdBy;
  DateTime createdAt;
  // Nur informativ: aus welchem Projekt/Gewerk das Foto stammt.
  String projectName;
  String gewerkName;

  DocumentationEntry({
    required this.id,
    required this.name,
    required this.fileType,
    required this.content,
    this.extension = '',
    required this.createdBy,
    DateTime? createdAt,
    this.projectName = '',
    this.gewerkName = '',
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'fileType': fileType,
        'content': content,
        'extension': extension,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'projectName': projectName,
        'gewerkName': gewerkName,
      };

  factory DocumentationEntry.fromMap(Map<String, dynamic> map) =>
      DocumentationEntry(
        id: map['id'] as String,
        name: map['name'] as String,
        fileType: map['fileType'] as String? ?? 'photo',
        content: map['content'] as String? ?? '',
        extension: map['extension'] as String? ?? '',
        createdBy: map['createdBy'] as String? ?? '',
        createdAt: DateTime.parse(map['createdAt'] as String),
        projectName: map['projectName'] as String? ?? '',
        gewerkName: map['gewerkName'] as String? ?? '',
      );
}
