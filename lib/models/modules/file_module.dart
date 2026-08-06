import 'gewerk_module.dart';

class FileVersion {
  String id;
  String label;
  DateTime createdAt;
  String createdBy;
  String content;

  FileVersion({
    required this.id,
    required this.label,
    DateTime? createdAt,
    this.createdBy = 'User',
    this.content = '',
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'content': content,
      };

  factory FileVersion.fromMap(Map<String, dynamic> map) => FileVersion(
        id: map['id'] as String,
        label: map['label'] as String? ?? '',
        createdAt: DateTime.parse(map['createdAt'] as String),
        createdBy: map['createdBy'] as String? ?? 'User',
        content: map['content'] as String? ?? '',
      );
}

// fileType: "pdf" | "photo" | "video" | "document"
class FileEntry {
  String id;
  String name;
  String fileType;
  List<FileVersion> versions;

  FileEntry({
    required this.id,
    required this.name,
    required this.fileType,
    List<FileVersion>? versions,
  }) : versions = versions ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'fileType': fileType,
        'versions': versions.map((v) => v.toMap()).toList(),
      };

  factory FileEntry.fromMap(Map<String, dynamic> map) => FileEntry(
        id: map['id'] as String,
        name: map['name'] as String,
        fileType: map['fileType'] as String? ?? 'document',
        versions: (map['versions'] as List<dynamic>? ?? [])
            .map((e) => FileVersion.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

class FileModule extends GewerkModule {
  static const moduleType = 'file';

  List<FileEntry> entries;

  FileModule(super.id, {List<FileEntry>? entries}) : entries = entries ?? [];

  @override
  String get type => moduleType;

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'id': id,
        'entries': entries.map((e) => e.toMap()).toList(),
      };

  factory FileModule.fromMap(Map<String, dynamic> map) => FileModule(
        map['id'] as String,
        entries: (map['entries'] as List<dynamic>? ?? [])
            .map((e) => FileEntry.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}
