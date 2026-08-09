// Eine Markierung auf einem Foto: entweder ein Kommentar-Pin (ein Punkt)
// oder eine Messung (zwei Punkte + Maßangabe wie "1,3 m"). x/y/x2/y2 sind
// relativ zur Bildgröße (0..1), damit die Markierung auf jedem Bildschirm
// an der richtigen Stelle sitzt.
class ImageAnnotation {
  static const typeComment = 'comment';
  static const typeMeasurement = 'measurement';

  String id;
  String type;
  double x;
  double y;
  double? x2;
  double? y2;
  String text;
  String createdBy;
  DateTime createdAt;

  ImageAnnotation({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.x2,
    this.y2,
    this.text = '',
    required this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'x': x,
        'y': y,
        'x2': x2,
        'y2': y2,
        'text': text,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ImageAnnotation.fromMap(Map<String, dynamic> map) => ImageAnnotation(
        id: map['id'] as String,
        type: map['type'] as String,
        x: (map['x'] as num).toDouble(),
        y: (map['y'] as num).toDouble(),
        x2: (map['x2'] as num?)?.toDouble(),
        y2: (map['y2'] as num?)?.toDouble(),
        text: map['text'] as String? ?? '',
        createdBy: map['createdBy'] as String? ?? '',
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
