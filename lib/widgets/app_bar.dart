import 'package:flutter/material.dart';

import '../screens/settings_screen.dart';

// Titel immer mittig: zeigt an, wo man sich gerade befindet (App-Name,
// Projektname oder Reitername). Rechts das Zahnrad für Optionen, links
// (vor dem Titel) optional Zurück + Plus, um die nächste Ebene darunter
// anzulegen.
PreferredSizeWidget buildAppBar(
  String title,
  BuildContext context,
  bool showBack, {
  VoidCallback? onCreate,
  String? createTooltip,
  VoidCallback? onSettings,
  // ✅ Kleiner Punkt auf dem Zahnrad, solange der Nutzer eine neue
  // Funktion (z.B. Zeitstatistik) noch nicht entdeckt hat, indem er die
  // Optionen dort einmal geöffnet hat.
  bool showSettingsBadge = false,
}) {
  final leadingIcons = <Widget>[
    if (showBack)
      IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    if (onCreate != null)
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: createTooltip,
        onPressed: onCreate,
      ),
  ];

  return AppBar(
    centerTitle: true,
    automaticallyImplyLeading: false,
    title: Text(title),
    leadingWidth: leadingIcons.isEmpty ? null : leadingIcons.length * 48.0,
    leading: leadingIcons.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: leadingIcons),
    actions: [
      IconButton(
        icon: showSettingsBadge
            ? const Badge(smallSize: 8, child: Icon(Icons.settings))
            : const Icon(Icons.settings),
        onPressed: onSettings ??
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SettingsScreen()),
              );
            },
      ),
    ],
  );
}
