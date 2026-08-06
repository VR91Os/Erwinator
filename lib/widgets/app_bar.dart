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
        icon: const Icon(Icons.settings),
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
