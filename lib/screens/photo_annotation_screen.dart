import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/image_annotation.dart';
import '../models/modules/file_module.dart';
import '../state/project_store.dart';
import '../state/settings_store.dart';
import '../utils/id_generator.dart';
import '../widgets/app_bar.dart';

// Foto mit Kommentar-Pins und Messungen. Gedrückt-halten = Kommentar an
// dieser Stelle. Doppeltipp = Messpunkt setzen; ein zweiter Doppeltipp
// schließt die Messstrecke ab und fragt nach der Maßangabe (z.B. "1,3 m").
// Beides wird sofort gespeichert – kein eigener Speichern-Knopf nötig. Nur
// auf nativen Plattformen erreichbar (Bild liegt lokal).
class PhotoAnnotationScreen extends StatefulWidget {
  final String projectId;
  final String gewerkId;
  final String moduleId;
  final String entryId;

  const PhotoAnnotationScreen({
    super.key,
    required this.projectId,
    required this.gewerkId,
    required this.moduleId,
    required this.entryId,
  });

  @override
  State<PhotoAnnotationScreen> createState() => _PhotoAnnotationScreenState();
}

class _PhotoAnnotationScreenState extends State<PhotoAnnotationScreen> {
  Offset? _pendingDoubleTapPos;
  // Startpunkt einer laufenden Messung (erster Doppeltipp). Ein zweiter
  // Doppeltipp schließt sie ab; Antippen des Markers bricht sie ab.
  Offset? _measurementStart;

  Offset _normalize(Offset local, Size boxSize) => Offset(
        (local.dx / boxSize.width).clamp(0.0, 1.0),
        (local.dy / boxSize.height).clamp(0.0, 1.0),
      );

  void _handleDoubleTap(Size boxSize) {
    final pos = _pendingDoubleTapPos;
    if (pos == null) return;
    final start = _measurementStart;
    if (start == null) {
      setState(() => _measurementStart = pos);
      return;
    }
    setState(() => _measurementStart = null);
    _showMeasurementDialog(_normalize(start, boxSize), _normalize(pos, boxSize));
  }

  void _showCommentDialog(Offset norm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Kommentar hinzufügen"),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(labelText: "Kommentar *"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                final actor =
                    context.read<SettingsStore>().currentUserKurzzeichen;
                context.read<ProjectStore>().addImageAnnotation(
                      widget.projectId,
                      widget.gewerkId,
                      widget.moduleId,
                      widget.entryId,
                      ImageAnnotation(
                        id: newId(),
                        type: ImageAnnotation.typeComment,
                        x: norm.dx,
                        y: norm.dy,
                        text: controller.text.trim(),
                        createdBy: actor,
                      ),
                    );
                Navigator.pop(dialogContext);
              },
              child: const Text("Speichern"),
            ),
          ],
        );
      },
    );
  }

  void _showMeasurementDialog(Offset start, Offset end) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Messung eintragen"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Maß *",
              hintText: "z.B. 1,3 m",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                final actor =
                    context.read<SettingsStore>().currentUserKurzzeichen;
                context.read<ProjectStore>().addImageAnnotation(
                      widget.projectId,
                      widget.gewerkId,
                      widget.moduleId,
                      widget.entryId,
                      ImageAnnotation(
                        id: newId(),
                        type: ImageAnnotation.typeMeasurement,
                        x: start.dx,
                        y: start.dy,
                        x2: end.dx,
                        y2: end.dy,
                        text: controller.text.trim(),
                        createdBy: actor,
                      ),
                    );
                Navigator.pop(dialogContext);
              },
              child: const Text("Speichern"),
            ),
          ],
        );
      },
    );
  }

  void _showAnnotationDetail(ImageAnnotation annotation) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            annotation.type == ImageAnnotation.typeComment
                ? "Kommentar"
                : "Messung",
          ),
          content: Text(
            annotation.text.isEmpty ? "(kein Text)" : annotation.text,
          ),
          actions: [
            TextButton(
              onPressed: () {
                context.read<ProjectStore>().removeImageAnnotation(
                      widget.projectId,
                      widget.gewerkId,
                      widget.moduleId,
                      widget.entryId,
                      annotation.id,
                    );
                Navigator.pop(dialogContext);
              },
              child: const Text("Löschen"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Schließen"),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _annotationOverlays(ImageAnnotation a, Size boxSize) {
    if (a.type == ImageAnnotation.typeComment) {
      return [
        Positioned(
          left: a.x * boxSize.width - 14,
          top: a.y * boxSize.height - 28,
          child: GestureDetector(
            onTap: () => _showAnnotationDetail(a),
            child: const Icon(Icons.location_pin, color: Colors.red, size: 28),
          ),
        ),
      ];
    }

    final p1 = Offset(a.x * boxSize.width, a.y * boxSize.height);
    final p2 = Offset(
      (a.x2 ?? a.x) * boxSize.width,
      (a.y2 ?? a.y) * boxSize.height,
    );
    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    return [
      Positioned.fill(
        child: CustomPaint(painter: _MeasurementLinePainter(p1, p2)),
      ),
      Positioned(
        left: mid.dx - 24,
        top: mid.dy - 12,
        child: GestureDetector(
          onTap: () => _showAnnotationDetail(a),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              a.text,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProjectStore>();
    final project = store.projects.firstWhere((p) => p.id == widget.projectId);
    final gewerk = project.gewerke.firstWhere((g) => g.id == widget.gewerkId);
    final module =
        gewerk.modules.firstWhere((m) => m.id == widget.moduleId) as FileModule;
    final entry = module.entries.firstWhere((e) => e.id == widget.entryId);
    final imagePath = entry.localImagePath;

    return Scaffold(
      appBar: buildAppBar(entry.name, context, true),
      body: imagePath == null
          ? const Center(child: Text("Kein lokales Bild vorhanden"))
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    "Gedrückt halten: Kommentar hinzufügen · Doppeltipp: "
                    "Messung starten, zweiter Doppeltipp: Messung "
                    "abschließen",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boxSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return ClipRect(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.file(
                                  File(imagePath),
                                  fit: BoxFit.contain,
                                ),
                              ),
                              for (final annotation in entry.annotations)
                                ..._annotationOverlays(annotation, boxSize),
                              if (_measurementStart != null)
                                Positioned(
                                  left: _measurementStart!.dx - 10,
                                  top: _measurementStart!.dy - 10,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _measurementStart = null),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: Colors.amber,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onDoubleTapDown: (details) =>
                                      _pendingDoubleTapPos =
                                          details.localPosition,
                                  onDoubleTap: () => _handleDoubleTap(boxSize),
                                  onLongPressStart: (details) =>
                                      _showCommentDialog(
                                    _normalize(details.localPosition, boxSize),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MeasurementLinePainter extends CustomPainter {
  final Offset p1;
  final Offset p2;
  _MeasurementLinePainter(this.p1, this.p2);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amber
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, paint);
    canvas.drawCircle(p1, 4, paint);
    canvas.drawCircle(p2, 4, paint);
  }

  @override
  bool shouldRepaint(covariant _MeasurementLinePainter oldDelegate) =>
      oldDelegate.p1 != p1 || oldDelegate.p2 != p2;
}
