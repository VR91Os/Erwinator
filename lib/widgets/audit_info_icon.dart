import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audit_entry.dart';
import '../state/settings_store.dart';

// Kleines, bewusst unauffälliges (i)-Icon: zeigt auf Antippen den Verlauf
// (wer hat erstellt/bearbeitet/abgehakt) und ist über die Option
// "Ersteller/Bearbeiter anzeigen" komplett abschaltbar.
class AuditInfoIcon extends StatelessWidget {
  final List<AuditEntry> history;

  const AuditInfoIcon({super.key, required this.history});

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    final showAuthorInfo =
        context.watch<SettingsStore>().settings.showAuthorInfo;
    if (!showAuthorInfo || history.isEmpty) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.info_outline, size: 14, color: Colors.grey),
      tooltip: "Verlauf",
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
      onPressed: () => _showHistory(context),
    );
  }

  void _showHistory(BuildContext context) {
    final sorted = [...history]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Verlauf"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: sorted.map((entry) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  child: Text(
                    entry.kurzzeichen,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                title: Text(entry.action),
                subtitle: Text(_formatTime(entry.timestamp)),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Schließen"),
          ),
        ],
      ),
    );
  }
}
