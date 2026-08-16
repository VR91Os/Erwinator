import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/finance_entry.dart';
import '../../models/modules/finance_module.dart';
import '../../models/project.dart';
import '../../state/project_store.dart';
import '../dialogs/finance_entry_dialog.dart';
import 'module_card.dart';

enum _AmountDisplay { gross, net, both }

class FinanceModuleWidget extends StatefulWidget {
  final String projectId;
  final String gewerkId;
  final FinanceModule module;

  const FinanceModuleWidget({
    super.key,
    required this.projectId,
    required this.gewerkId,
    required this.module,
  });

  @override
  State<FinanceModuleWidget> createState() => _FinanceModuleWidgetState();
}

class _FinanceModuleWidgetState extends State<FinanceModuleWidget> {
  _AmountDisplay _display = _AmountDisplay.gross;

  String _formatAmount(double value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

  String _typeLabel(String documentType) =>
      documentType == FinanceDocumentType.angebot ? 'Angebot' : 'Rechnung';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProjectStore>();
    Project? project;
    for (final p in store.projects) {
      if (p.id == widget.projectId) project = p;
    }
    if (project == null) return const SizedBox.shrink();
    final resolvedProject = project;
    final entries = resolvedProject.financeEntries
        .where((e) => e.gewerkId == widget.gewerkId)
        .toList()
      ..sort((a, b) => (b.date ?? b.createdAt).compareTo(a.date ?? a.createdAt));

    final angebote = entries
        .where((e) => e.documentType == FinanceDocumentType.angebot)
        .toList();
    final rechnungen = entries
        .where((e) => e.documentType == FinanceDocumentType.rechnung)
        .toList();

    double sumGross(List<FinanceEntry> list) =>
        list.fold(0.0, (sum, e) => sum + e.amountGross);
    double? sumNet(List<FinanceEntry> list) {
      if (list.every((e) => e.amountNet == null)) return null;
      return list.fold<double>(0.0, (sum, e) => sum + (e.amountNet ?? 0));
    }

    Widget summaryLine(String label, List<FinanceEntry> list) {
      final gross = sumGross(list);
      final net = sumNet(list);
      final parts = <String>[];
      if (_display == _AmountDisplay.gross || _display == _AmountDisplay.both) {
        parts.add('Brutto ${_formatAmount(gross)}');
      }
      if (_display == _AmountDisplay.net || _display == _AmountDisplay.both) {
        parts.add(net == null ? 'Netto –' : 'Netto ${_formatAmount(net)}');
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          '$label (${list.length}): ${parts.join(' · ')}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }

    Widget entryRow(FinanceEntry entry) {
      final amountText = _display == _AmountDisplay.net
          ? (entry.amountNet == null ? '–' : _formatAmount(entry.amountNet!))
          : _formatAmount(entry.amountGross);
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(
          entry.documentType == FinanceDocumentType.angebot
              ? Icons.description_outlined
              : Icons.receipt_long,
          size: 20,
        ),
        title: Text(
          '${_typeLabel(entry.documentType)} · $amountText'
          '${entry.autoDetected ? ' 🔍' : ''}',
        ),
        subtitle: Text([
          if (entry.date != null)
            '${entry.date!.day}.${entry.date!.month}.${entry.date!.year}',
          if (entry.note.isNotEmpty) entry.note,
        ].join(' · ')),
        onTap: () => showFinanceEntryDialog(
          context,
          projectId: widget.projectId,
          gewerke: resolvedProject.gewerke,
          existing: entry,
        ),
      );
    }

    return ModuleCard(
      projectId: widget.projectId,
      gewerkId: widget.gewerkId,
      moduleId: widget.module.id,
      icon: "💶",
      defaultTitle: "Finanzen",
      label: widget.module.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: SegmentedButton<_AmountDisplay>(
              segments: const [
                ButtonSegment(value: _AmountDisplay.gross, label: Text("Brutto")),
                ButtonSegment(value: _AmountDisplay.net, label: Text("Netto")),
                ButtonSegment(value: _AmountDisplay.both, label: Text("Beide")),
              ],
              selected: {_display},
              onSelectionChanged: (s) => setState(() => _display = s.first),
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                "Noch keine Angebote/Rechnungen erfasst.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else ...[
            if (rechnungen.isNotEmpty) summaryLine('Rechnungen', rechnungen),
            if (angebote.isNotEmpty) summaryLine('Angebote', angebote),
            const Divider(),
            ...entries.map(entryRow),
          ],
          const SizedBox(height: 6),
          ElevatedButton.icon(
            onPressed: () => showFinanceEntryDialog(
              context,
              projectId: widget.projectId,
              gewerke: resolvedProject.gewerke,
              initialGewerkId: widget.gewerkId,
            ),
            icon: const Icon(Icons.add),
            label: const Text("Eintrag hinzufügen"),
          ),
        ],
      ),
    );
  }
}
