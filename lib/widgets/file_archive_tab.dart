import 'package:flutter/material.dart';

import '../models/gewerk.dart';
import '../models/modules/file_module.dart';
import '../models/project.dart';
import 'audit_info_icon.dart';

class _FileRef {
  final Gewerk gewerk;
  final FileModule module;
  final FileEntry entry;
  _FileRef(this.gewerk, this.module, this.entry);

  // Die erste Version ist immer die beim Anlegen hochgeladene.
  String get creator =>
      entry.versions.isEmpty ? '' : entry.versions.first.createdBy;
  DateTime? get uploadedAt =>
      entry.versions.isEmpty ? null : entry.versions.first.createdAt;
}

const _allTypes = 'alle';

// Zeigt alle Dateien aus allen File-Ablage-Modulen des Projekts gesammelt
// an, durchsuchbar über Namen/Gewerk und filterbar nach Dateityp, Ersteller
// und Hochlade-Zeitraum. Ein Treffer springt zum jeweiligen Gewerk-Reiter,
// da Hoch-/Neu-Versionieren dort passiert.
class FileArchiveTab extends StatefulWidget {
  final Project project;
  final ValueChanged<String> onOpenGewerk;

  const FileArchiveTab({
    super.key,
    required this.project,
    required this.onOpenGewerk,
  });

  @override
  State<FileArchiveTab> createState() => _FileArchiveTabState();
}

class _FileArchiveTabState extends State<FileArchiveTab> {
  String query = '';
  String typeFilter = _allTypes;
  String? creatorFilter;
  DateTime? fromDate;
  DateTime? toDate;

  List<_FileRef> get _allFiles {
    final refs = <_FileRef>[];
    for (final gewerk in widget.project.gewerke) {
      for (final module in gewerk.modules.whereType<FileModule>()) {
        for (final entry in module.entries) {
          refs.add(_FileRef(gewerk, module, entry));
        }
      }
    }
    return refs;
  }

  IconData _iconFor(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'photo':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _typeLabel(String fileType) {
    switch (fileType) {
      case 'pdf':
        return 'PDF';
      case 'photo':
        return 'Foto';
      case 'video':
        return 'Video';
      default:
        return 'Dokument';
    }
  }

  bool get _hasActiveFilters =>
      typeFilter != _allTypes ||
      creatorFilter != null ||
      fromDate != null ||
      toDate != null;

  void _resetFilters() {
    setState(() {
      typeFilter = _allTypes;
      creatorFilter = null;
      fromDate = null;
      toDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allFiles = _allFiles;
    final creators = allFiles.map((ref) => ref.creator).where((c) => c.isNotEmpty).toSet().toList()
      ..sort();

    final q = query.trim().toLowerCase();
    final from = fromDate == null
        ? null
        : DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
    final to = toDate == null
        ? null
        : DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59);

    final results = allFiles.where((ref) {
      if (q.isNotEmpty &&
          !ref.entry.name.toLowerCase().contains(q) &&
          !ref.gewerk.name.toLowerCase().contains(q)) {
        return false;
      }
      if (typeFilter != _allTypes && ref.entry.fileType != typeFilter) {
        return false;
      }
      if (creatorFilter != null && ref.creator != creatorFilter) {
        return false;
      }
      final uploadedAt = ref.uploadedAt;
      if (from != null && (uploadedAt == null || uploadedAt.isBefore(from))) {
        return false;
      }
      if (to != null && (uploadedAt == null || uploadedAt.isAfter(to))) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) =>
          a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: "Dateien durchsuchen…",
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              value: typeFilter,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(
                    value: _allTypes, child: Text("Alle Typen")),
                const DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                const DropdownMenuItem(value: 'photo', child: Text('Foto')),
                const DropdownMenuItem(value: 'video', child: Text('Video')),
                const DropdownMenuItem(
                    value: 'document', child: Text('Dokument')),
              ],
              onChanged: (value) =>
                  setState(() => typeFilter = value ?? _allTypes),
            ),
            DropdownButton<String?>(
              value: creatorFilter,
              hint: const Text("Ersteller"),
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text("Alle Ersteller")),
                ...creators.map((c) =>
                    DropdownMenuItem<String?>(value: c, child: Text(c))),
              ],
              onChanged: (value) => setState(() => creatorFilter = value),
            ),
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: fromDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => fromDate = picked);
              },
              child: Text(fromDate == null
                  ? "Hochgeladen ab…"
                  : "Ab ${fromDate!.day}.${fromDate!.month}.${fromDate!.year}"),
            ),
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: toDate ?? DateTime.now(),
                  firstDate: fromDate ?? DateTime.now().subtract(const Duration(days: 3650)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => toDate = picked);
              },
              child: Text(toDate == null
                  ? "bis…"
                  : "bis ${toDate!.day}.${toDate!.month}.${toDate!.year}"),
            ),
            if (_hasActiveFilters)
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.filter_alt_off, size: 16),
                label: const Text("Filter zurücksetzen"),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    allFiles.isEmpty
                        ? "Noch keine Dateien hochgeladen"
                        : "Keine Treffer",
                  ),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final ref = results[index];
                    final uploadedAt = ref.uploadedAt;
                    return ListTile(
                      leading: Icon(_iconFor(ref.entry.fileType)),
                      title: Text(ref.entry.name),
                      subtitle: Text(
                        "${ref.gewerk.name}"
                        "${ref.module.label.isEmpty ? '' : ' · ${ref.module.label}'}"
                        " · ${_typeLabel(ref.entry.fileType)}"
                        " · ${ref.entry.versions.length} Version"
                        "${ref.entry.versions.length == 1 ? '' : 'en'}"
                        "${ref.creator.isEmpty ? '' : ' · von ${ref.creator}'}"
                        "${uploadedAt == null ? '' : ' am ${uploadedAt.day}.${uploadedAt.month}.${uploadedAt.year}'}",
                      ),
                      trailing: AuditInfoIcon(history: ref.entry.history),
                      onTap: () => widget.onOpenGewerk(ref.gewerk.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
