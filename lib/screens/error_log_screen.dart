import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/error_log_service.dart';

String _csvField(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _formatTimestamp(DateTime time) =>
    "${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}.${time.year} "
    "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:"
    "${time.second.toString().padLeft(2, '0')}";

Future<void> _exportErrorLog(BuildContext context, List<AppErrorEntry> entries) async {
  final buffer = StringBuffer('Zeit;Meldung;Detail\r\n');
  for (final entry in entries) {
    buffer.write(_csvField(_formatTimestamp(entry.time)));
    buffer.write(';');
    buffer.write(_csvField(entry.message));
    buffer.write(';');
    buffer.write(_csvField(entry.detail ?? ''));
    buffer.write('\r\n');
  }

  try {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/fehlerprotokoll_${DateTime.now().millisecondsSinceEpoch}.csv');
    // UTF-8 BOM, damit Excel die Umlaute korrekt erkennt statt sie als
    // Mojibake darzustellen.
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);
    await Share.shareXFiles([XFile(file.path)], text: 'Baustelli Fehlerprotokoll');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export fehlgeschlagen: $e')),
      );
    }
  }
}

// Zeigt unerwartete Fehler, die der globale Error-Handler (main.dart)
// aufgefangen hat – damit sich Probleme auch auf dem Handy nachvollziehen
// lassen, ohne eine Dev-Konsole mitlaufen zu haben.
class ErrorLogScreen extends StatelessWidget {
  const ErrorLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ErrorLogService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fehlerprotokoll"),
        actions: [
          if (service.entries.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: "Als CSV exportieren",
              onPressed: () => _exportErrorLog(context, service.entries),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: "Protokoll leeren",
              onPressed: service.clear,
            ),
          ],
        ],
      ),
      body: service.entries.isEmpty
          ? const Center(child: Text("Keine Fehler protokolliert"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: service.entries.length,
              itemBuilder: (context, index) {
                final entry = service.entries[index];
                return Card(
                  child: ExpansionTile(
                    title: Text(entry.message),
                    subtitle: Text(
                      "${entry.time.day}.${entry.time.month}.${entry.time.year} "
                      "${entry.time.hour.toString().padLeft(2, '0')}:"
                      "${entry.time.minute.toString().padLeft(2, '0')}",
                    ),
                    children: [
                      if (entry.detail != null && entry.detail!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            entry.detail!,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
