import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/audit_entry.dart';
import '../../models/finance_entry.dart';
import '../../models/gewerk.dart';
import '../../state/project_store.dart';
import '../../state/settings_store.dart';
import '../../utils/amount_format.dart';
import '../../utils/finance_detection.dart';
import '../../utils/id_generator.dart';
import '../../utils/safe_notify.dart';

// Normaler österreichischer Umsatzsteuersatz - nur als Rechenhilfe, falls
// Netto/Brutto weder im PDF erkannt noch manuell eingetragen wurde. Ergibt
// bei abweichendem Steuersatz (z.B. 10%/13%) einen falschen Vorschlag, den
// der Nutzer dann selbst überschreiben muss - deshalb nie automatisch
// gespeichert, sondern nur als vorausgefüllter, weiter editierbarer Wert.
const _austrianVatFactor = 1.20;

// Erfassen/Bearbeiten eines Angebots/einer Rechnung. Wird sowohl beim
// PDF-Upload (mit [detected]-Vorbefüllung, nie automatisch gespeichert
// ohne diesen Dialog) als auch manuell über "+ Eintrag" im Finanzen-Modul
// oder der projektweiten Übersicht geöffnet.
//
// [existing] != null -> Bearbeiten eines vorhandenen Eintrags (Gewerk fest,
// Löschen möglich). [existing] == null -> Neuanlage; [initialGewerkId]
// legt das Gewerk fest, oder [allowGewerkPicker] zeigt eine Auswahl (für
// Aufrufe ohne festen Gewerk-Kontext, z.B. aus der projektweiten Übersicht).
void showFinanceEntryDialog(
  BuildContext context, {
  required String projectId,
  required List<Gewerk> gewerke,
  String? initialGewerkId,
  bool allowGewerkPicker = false,
  String? fileModuleId,
  String? fileEntryId,
  FinanceEntry? existing,
  FinanceDetectionResult? detected,
}) {
  final store = context.read<ProjectStore>();
  final actor = context.read<SettingsStore>().currentUserKurzzeichen;

  // Bei einer neuen Datei-Version mit frischer Erkennung (existing UND
  // detected gesetzt, siehe file_module_widget.dart) gewinnt die neue
  // Erkennung über den alten gespeicherten Wert, da die neue Version
  // vermutlich aktuellere Zahlen enthält.
  final hasFreshDetection = detected != null && !detected.isEmpty;
  String? gewerkId = existing?.gewerkId ??
      initialGewerkId ??
      (gewerke.isEmpty ? null : gewerke.first.id);
  String documentType = detected?.documentType ??
      existing?.documentType ??
      FinanceDocumentType.rechnung;
  final grossController = TextEditingController(
    text: formatAmountForInput(detected?.amountGross ?? existing?.amountGross),
  );
  final netController = TextEditingController(
    text: formatAmountForInput(detected?.amountNet ?? existing?.amountNet),
  );
  final noteController = TextEditingController(text: existing?.note ?? '');
  DateTime? date = existing?.date;
  final autoDetected = hasFreshDetection ? true : (existing?.autoDetected ?? false);
  final showGewerkPicker = existing == null && allowGewerkPicker;

  // Rechnet Netto/Brutto mit dem normalen österreichischen USt-Satz
  // gegenseitig hoch/runter, solange das jeweils andere Feld leer ist oder
  // selbst nur so errechnet wurde - eine echte Eingabe (Erkennung oder
  // Tippen) wird nie überschrieben.
  var nettoIsCalculated = false;
  var grossIsCalculated = false;
  var syncingAmounts = false;
  void syncNettoFromGross() {
    final gross = parseAmount(grossController.text);
    if (gross == null) return;
    syncingAmounts = true;
    netController.text =
        formatAmountForInput(roundToCents(gross / _austrianVatFactor));
    syncingAmounts = false;
    nettoIsCalculated = true;
  }

  void syncGrossFromNetto() {
    final netto = parseAmount(netController.text);
    if (netto == null) return;
    syncingAmounts = true;
    grossController.text =
        formatAmountForInput(roundToCents(netto * _austrianVatFactor));
    syncingAmounts = false;
    grossIsCalculated = true;
  }

  grossController.addListener(() {
    if (syncingAmounts) return;
    grossIsCalculated = false;
    if (netController.text.isEmpty || nettoIsCalculated) {
      syncNettoFromGross();
    }
  });
  netController.addListener(() {
    if (syncingAmounts) return;
    nettoIsCalculated = false;
    if (grossController.text.isEmpty || grossIsCalculated) {
      syncGrossFromNetto();
    }
  });
  // Direkt beim Öffnen einmalig nachziehen, falls PDF-Erkennung oder ein
  // bestehender Eintrag nur eine der beiden Seiten geliefert hat.
  if (netController.text.isEmpty && grossController.text.isNotEmpty) {
    syncNettoFromGross();
  } else if (grossController.text.isEmpty && netController.text.isNotEmpty) {
    syncGrossFromNetto();
  }

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existing == null
                ? "Angebot/Rechnung erfassen"
                : "Eintrag bearbeiten"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (autoDetected)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        "Automatisch erkannt – bitte prüfen und bestätigen.",
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  if (showGewerkPicker) ...[
                    DropdownButtonFormField<String>(
                      initialValue: gewerkId,
                      decoration: const InputDecoration(labelText: "Gewerk *"),
                      items: gewerke
                          .map((g) => DropdownMenuItem(
                                value: g.id,
                                child: Text(g.name),
                              ))
                          .toList(),
                      onChanged: (value) => setDialogState(() => gewerkId = value),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: FinanceDocumentType.rechnung,
                        label: Text("Rechnung"),
                      ),
                      ButtonSegment(
                        value: FinanceDocumentType.angebot,
                        label: Text("Angebot"),
                      ),
                    ],
                    selected: {documentType},
                    onSelectionChanged: (selection) =>
                        setDialogState(() => documentType = selection.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: grossController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: "Brutto-Gesamtbetrag *",
                      suffixText: "€",
                      hintText: "z.B. 1.234,56",
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: netController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: "Netto (optional)",
                      suffixText: "€",
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      "Wird bei 20% USt automatisch aus dem jeweils anderen "
                      "Betrag berechnet, solange nichts eingetragen ist – "
                      "bei abweichendem Steuersatz einfach überschreiben.",
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          date == null
                              ? "Kein Datum"
                              : "Datum: ${date!.day}.${date!.month}.${date!.year}",
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => date = picked);
                          }
                        },
                        child: const Text("Wählen"),
                      ),
                    ],
                  ),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: "Notiz (optional)",
                      hintText: "z.B. Firma",
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (existing != null)
                TextButton(
                  onPressed: () {
                    popDialogThen(
                      dialogContext,
                      () => store.removeFinanceEntry(projectId, existing.id),
                    );
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("Löschen"),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Abbrechen"),
              ),
              ElevatedButton(
                onPressed: () {
                  final gross = parseAmount(grossController.text);
                  final resolvedGewerkId = gewerkId;
                  if (gross == null || resolvedGewerkId == null) return;
                  final net = parseAmount(netController.text);
                  final note = noteController.text.trim();
                  popDialogThen(dialogContext, () {
                    if (existing == null) {
                      store.addFinanceEntry(
                        projectId,
                        FinanceEntry(
                          id: newId(),
                          gewerkId: resolvedGewerkId,
                          fileModuleId: fileModuleId,
                          fileEntryId: fileEntryId,
                          documentType: documentType,
                          amountGross: gross,
                          amountNet: net,
                          date: date,
                          note: note,
                          autoDetected: autoDetected,
                          createdBy: actor,
                          history: [
                            AuditEntry(kurzzeichen: actor, action: 'erfasst'),
                          ],
                        ),
                      );
                    } else {
                      existing.gewerkId = resolvedGewerkId;
                      existing.documentType = documentType;
                      existing.amountGross = gross;
                      existing.amountNet = net;
                      existing.date = date;
                      existing.note = note;
                      existing.updatedAt = DateTime.now();
                      existing.history.add(
                          AuditEntry(kurzzeichen: actor, action: 'bearbeitet'));
                      store.updateFinanceEntry(projectId, existing);
                    }
                  });
                },
                child: const Text("Speichern"),
              ),
            ],
          );
        },
      );
    },
  ).then((_) {
    grossController.dispose();
    netController.dispose();
    noteController.dispose();
  });
}
