import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/project_store.dart';

class ModuleCard extends StatelessWidget {
  final String projectId;
  final String gewerkId;
  final String moduleId;
  final String icon;
  final String defaultTitle;
  final String label;
  final Widget child;

  const ModuleCard({
    super.key,
    required this.projectId,
    required this.gewerkId,
    required this.moduleId,
    required this.icon,
    required this.defaultTitle,
    this.label = '',
    required this.child,
  });

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Modul entfernen?"),
          content: Text(
            '"${label.isEmpty ? defaultTitle : label}" wird inklusive '
            'aller darin erfassten Einträge entfernt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext);
                context
                    .read<ProjectStore>()
                    .removeModule(projectId, gewerkId, moduleId);
              },
              child: const Text("Entfernen"),
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: label);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Modul umbenennen"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: "Name",
              hintText: defaultTitle,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<ProjectStore>().renameModule(
                      projectId,
                      gewerkId,
                      moduleId,
                      controller.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final title = "$icon ${label.isEmpty ? defaultTitle : label}";

    // Die Karte bleibt bewusst immer hell, unabhängig vom Dunkelmodus.
    // Theme-Override für den ganzen Karten-Inhalt statt einzelne Text-/
    // Eingabefelder manuell einzufärben - sonst bräuchte JEDES verschachtelte
    // Widget (z.B. die Telefon-/Email-Felder in ContactModuleWidget) eine
    // eigene, leicht vergessene Farbkorrektur. Gleiche Werte wie das
    // App-weite Hell-Theme in main.dart, damit Buttons/Eingaben auf der
    // Karte unabhängig vom aktuellen App-Design konsistent aussehen.
    //
    // textTheme.apply(...) UND colorScheme-Override zusätzlich nötig:
    // Material 3 leitet aus primarySwatch: Colors.grey ein Farbschema mit
    // einem gedämpften, gräulichen statt kräftigem Schwarz für
    // onSurface/Textfarben ab - auf der ohnehin schon eher blassen Karte
    // wirkte der Modul-Text dadurch zu hell/verwaschen statt schwarz.
    // textTheme.apply() reicht allein NICHT: einige M3-Widgets (z.B.
    // ListTile/CheckboxListTile) leiten ihre Standard-Textfarbe direkt aus
    // colorScheme.onSurface statt aus dem TextTheme ab.
    final lightModuleTheme =
        ThemeData(primarySwatch: Colors.grey, brightness: Brightness.light);
    return Theme(
      data: lightModuleTheme.copyWith(
        colorScheme: lightModuleTheme.colorScheme.copyWith(
          onSurface: Colors.black87,
          onSurfaceVariant: Colors.black87,
        ),
        textTheme: lightModuleTheme.textTheme.apply(
          bodyColor: Colors.black87,
          displayColor: Colors.black87,
        ),
      ),
      // Ohne dieses Material bleibt der Theme-Override oben für einfache
      // Text-Widgets (z.B. die Modul-Überschrift direkt unten) wirkungslos:
      // deren Standardfarbe kommt aus dem ambienten DefaultTextStyle, das
      // vom NÄCHSTEN Material-Vorfahren gesetzt wird - ohne ein eigenes
      // Material HIER bleibt das der äußere, dunkelmodus-abhängige Scaffold
      // weiter oben im Baum, unser Theme-Override wird also nie neu
      // ausgewertet. Widgets mit eigener Theme.of(context)-Abfrage (z.B.
      // CheckboxListTile) waren davon nicht betroffen, deshalb fiel es nur
      // bei der Überschrift auf.
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: "Modul umbenennen",
                    onPressed: () => _showRenameDialog(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: "Modul entfernen",
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
