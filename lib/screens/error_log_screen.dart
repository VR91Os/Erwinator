import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/error_log_service.dart';

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
          if (service.entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: "Protokoll leeren",
              onPressed: service.clear,
            ),
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
