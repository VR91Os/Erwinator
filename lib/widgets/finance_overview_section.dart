import 'package:flutter/material.dart';

import '../models/finance_entry.dart';
import '../models/gewerk.dart';
import '../models/project.dart';
import 'dialogs/finance_entry_dialog.dart';

enum _AmountDisplay { gross, net, both }

// Projektweite Gesamtübersicht (eigener Reiter, wie Zeitstatistik): fasst
// Project.financeEntries über ALLE Gewerke hinweg zusammen und gruppiert
// nach Gewerk - unabhängig davon, ob ein Gewerk selbst ein Finanzen-Modul
// als Reiter hat. Angebote und Rechnungen werden nie zu einer gemeinsamen
// Summe verschmolzen (ein Angebot ist unverbindlich, eine Rechnung eine
// tatsächliche Zahlungsverpflichtung).
class FinanceOverviewSection extends StatefulWidget {
  final Project project;

  const FinanceOverviewSection({super.key, required this.project});

  @override
  State<FinanceOverviewSection> createState() => _FinanceOverviewSectionState();
}

class _FinanceOverviewSectionState extends State<FinanceOverviewSection> {
  _AmountDisplay _display = _AmountDisplay.gross;

  String _formatAmount(double value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

  double _sumGross(List<FinanceEntry> list) =>
      list.fold<double>(0.0, (sum, e) => sum + e.amountGross);

  double? _sumNet(List<FinanceEntry> list) {
    if (list.every((e) => e.amountNet == null)) return null;
    return list.fold<double>(0.0, (sum, e) => sum + (e.amountNet ?? 0));
  }

  String _amountSummary(List<FinanceEntry> list) {
    final gross = _sumGross(list);
    final net = _sumNet(list);
    final parts = <String>[];
    if (_display == _AmountDisplay.gross || _display == _AmountDisplay.both) {
      parts.add('Brutto ${_formatAmount(gross)}');
    }
    if (_display == _AmountDisplay.net || _display == _AmountDisplay.both) {
      parts.add(net == null ? 'Netto –' : 'Netto ${_formatAmount(net)}');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final entries = project.financeEntries;
    final angebote = entries
        .where((e) => e.documentType == FinanceDocumentType.angebot)
        .toList();
    final rechnungen = entries
        .where((e) => e.documentType == FinanceDocumentType.rechnung)
        .toList();

    final gewerkById = <String, Gewerk>{for (final g in project.gewerke) g.id: g};
    final byGewerk = <String, List<FinanceEntry>>{};
    for (final entry in entries) {
      byGewerk.putIfAbsent(entry.gewerkId, () => []).add(entry);
    }

    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Gesamtübersicht",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SegmentedButton<_AmountDisplay>(
              segments: const [
                ButtonSegment(value: _AmountDisplay.gross, label: Text("Brutto")),
                ButtonSegment(value: _AmountDisplay.net, label: Text("Netto")),
                ButtonSegment(value: _AmountDisplay.both, label: Text("Beide")),
              ],
              selected: {_display},
              onSelectionChanged: (s) => setState(() => _display = s.first),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "Noch keine Angebote/Rechnungen erfasst – entweder direkt bei "
              "einer PDF-Datei in der File-Ablage eines Gewerks oder unten "
              "manuell.",
              style: TextStyle(color: Colors.grey),
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rechnungen (${rechnungen.length}): '
                      '${_amountSummary(rechnungen)}'),
                  const SizedBox(height: 4),
                  Text('Angebote (${angebote.length}): '
                      '${_amountSummary(angebote)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Nach Gewerk",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          ...byGewerk.entries.map((group) {
            final gewerk = gewerkById[group.key];
            final list = group.value;
            final groupAngebote = list
                .where((e) => e.documentType == FinanceDocumentType.angebot)
                .toList();
            final groupRechnungen = list
                .where((e) => e.documentType == FinanceDocumentType.rechnung)
                .toList();
            return ExpansionTile(
              title: Text(gewerk?.name ?? '(entferntes Gewerk)'),
              subtitle: Text(
                'Rechnungen: ${_amountSummary(groupRechnungen)}'
                '${groupAngebote.isEmpty ? '' : ' · Angebote: ${_amountSummary(groupAngebote)}'}',
              ),
              children: list.map((entry) {
                final amountText = _display == _AmountDisplay.net
                    ? (entry.amountNet == null
                        ? '–'
                        : _formatAmount(entry.amountNet!))
                    : _formatAmount(entry.amountGross);
                return ListTile(
                  dense: true,
                  leading: Icon(
                    entry.documentType == FinanceDocumentType.angebot
                        ? Icons.description_outlined
                        : Icons.receipt_long,
                    size: 20,
                  ),
                  title: Text(
                    '${entry.documentType == FinanceDocumentType.angebot ? 'Angebot' : 'Rechnung'} · $amountText'
                    '${entry.autoDetected ? ' 🔍' : ''}',
                  ),
                  subtitle: Text([
                    if (entry.date != null)
                      '${entry.date!.day}.${entry.date!.month}.${entry.date!.year}',
                    if (entry.note.isNotEmpty) entry.note,
                  ].join(' · ')),
                  onTap: () => showFinanceEntryDialog(
                    context,
                    projectId: project.id,
                    gewerke: project.gewerke,
                    existing: entry,
                  ),
                );
              }).toList(),
            );
          }),
        ],
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: project.gewerke.isEmpty
              ? null
              : () => showFinanceEntryDialog(
                    context,
                    projectId: project.id,
                    gewerke: project.gewerke,
                    allowGewerkPicker: true,
                  ),
          icon: const Icon(Icons.add),
          label: const Text("Eintrag hinzufügen"),
        ),
      ],
    );
  }
}
