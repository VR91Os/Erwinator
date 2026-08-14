import '../../utils/id_merge.dart';
import '../audit_entry.dart';
import '../image_annotation.dart';
import 'gewerk_module.dart';

class FileVersion {
  String id;
  String label;
  DateTime createdAt;
  String createdBy;
  // Base64-kodierter Dateiinhalt. Wird mit den Projektdaten synchronisiert,
  // damit die Datei auch von anderen Projekt-Mitgliedern wieder abrufbar
  // ist. Leer bei Versionen, die vor Einführung dieser Speicherung
  // angelegt wurden.
  String content;
  // Ursprüngliche Dateiendung (ohne Punkt, z.B. "pdf", "docx"), damit der
  // Download denselben Dateityp wiederherstellt.
  String extension;

  FileVersion({
    required this.id,
    required this.label,
    DateTime? createdAt,
    this.createdBy = 'User',
    this.content = '',
    this.extension = '',
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'content': content,
        'extension': extension,
      };

  factory FileVersion.fromMap(Map<String, dynamic> map) => FileVersion(
        id: map['id'] as String,
        label: map['label'] as String? ?? '',
        createdAt: DateTime.parse(map['createdAt'] as String),
        createdBy: map['createdBy'] as String? ?? 'User',
        content: map['content'] as String? ?? '',
        extension: map['extension'] as String? ?? '',
      );
}

// fileType: "pdf" | "photo" | "video" | "document"
class FileEntry {
  String id;
  String name;
  String fileType;
  List<FileVersion> versions;

  // Verlauf: wer hat hochgeladen/eine neue Version hinzugefügt.
  List<AuditEntry> history;

  // Lokaler Dateipfad des tatsächlichen Bildes für die Foto-Bearbeitung
  // (Kommentar-Pins/Messungen). Nur auf nativen Plattformen befüllt – im
  // Web gibt es kein Dateisystem dafür, dort bleibt es null. Bewusst
  // NICHT über den Sync-Merge von einer anderen Seite übernommen (siehe
  // mergeFrom) – ein Pfad ist immer nur auf dem Gerät gültig, das ihn
  // gesetzt hat.
  String? localImagePath;
  List<ImageAnnotation> annotations;
  DateTime updatedAt;

  // Neueste Version (nach Erstellzeitpunkt), oder null ohne Versionen.
  FileVersion? get latestVersion {
    if (versions.isEmpty) return null;
    return ([...versions]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        .first;
  }

  FileEntry({
    required this.id,
    required this.name,
    required this.fileType,
    List<FileVersion>? versions,
    List<AuditEntry>? history,
    this.localImagePath,
    List<ImageAnnotation>? annotations,
    DateTime? updatedAt,
  })  : versions = versions ?? [],
        history = history ?? [],
        annotations = annotations ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'fileType': fileType,
        'versions': versions.map((v) => v.toMap()).toList(),
        'history': history.map((h) => h.toMap()).toList(),
        'localImagePath': localImagePath,
        'annotations': annotations.map((a) => a.toMap()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FileEntry.fromMap(Map<String, dynamic> map) => FileEntry(
        id: map['id'] as String,
        name: map['name'] as String,
        fileType: map['fileType'] as String? ?? 'document',
        versions: (map['versions'] as List<dynamic>? ?? [])
            .map((e) => FileVersion.fromMap(e as Map<String, dynamic>))
            .toList(),
        history: (map['history'] as List<dynamic>? ?? [])
            .map((e) => AuditEntry.fromMap(e as Map<String, dynamic>))
            .toList(),
        localImagePath: map['localImagePath'] as String?,
        annotations: (map['annotations'] as List<dynamic>? ?? [])
            .map((e) => ImageAnnotation.fromMap(e as Map<String, dynamic>))
            .toList(),
        updatedAt: map['updatedAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(map['updatedAt'] as String),
      );

  // Sync-Merge (Option C): Versionen sind unveränderlich (nur neue kommen
  // dazu) -> reine ID-Vereinigung. Markierungen können gelöscht werden ->
  // Tombstones berücksichtigen. localImagePath bleibt bewusst immer der
  // lokale Wert dieses Geräts.
  FileEntry mergeFrom(FileEntry remote, Map<String, DateTime> tombstones) {
    final winner = newerOf(this, remote, (e) => e.updatedAt);
    return FileEntry(
      id: id,
      name: winner.name,
      fileType: winner.fileType,
      updatedAt: winner.updatedAt,
      localImagePath: localImagePath,
      versions: mergeById<FileVersion>(
        local: versions,
        remote: remote.versions,
        idOf: (v) => v.id,
        updatedAtOf: (v) => v.createdAt,
        combine: (l, r) => l,
      ),
      annotations: mergeById<ImageAnnotation>(
        local: annotations,
        remote: remote.annotations,
        idOf: (a) => a.id,
        updatedAtOf: (a) => a.createdAt,
        combine: (l, r) => l,
        tombstones: tombstones,
      ),
      history: mergeHistory(history, remote.history),
    );
  }
}

class FileModule extends GewerkModule {
  static const moduleType = 'file';

  List<FileEntry> entries;

  FileModule(super.id, {super.label, super.updatedAt, List<FileEntry>? entries})
      : entries = entries ?? [];

  @override
  String get type => moduleType;

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'id': id,
        'label': label,
        'updatedAt': updatedAt.toIso8601String(),
        'entries': entries.map((e) => e.toMap()).toList(),
      };

  factory FileModule.fromMap(Map<String, dynamic> map) => FileModule(
        map['id'] as String,
        label: map['label'] as String? ?? '',
        updatedAt: map['updatedAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(map['updatedAt'] as String),
        entries: (map['entries'] as List<dynamic>? ?? [])
            .map((e) => FileEntry.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  GewerkModule mergeFrom(GewerkModule remote, Map<String, DateTime> tombstones) {
    if (remote is! FileModule) return this;
    final winner = newerOf(this, remote, (m) => m.updatedAt);
    return FileModule(
      id,
      label: winner.label,
      updatedAt: winner.updatedAt,
      entries: mergeById<FileEntry>(
        local: entries,
        remote: remote.entries,
        idOf: (e) => e.id,
        updatedAtOf: (e) => e.updatedAt,
        combine: (l, r) => l.mergeFrom(r, tombstones),
        tombstones: tombstones,
      ),
    );
  }
}
