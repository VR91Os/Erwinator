import 'package:flutter/foundation.dart';

import '../models/documentation_entry.dart';
import '../repositories/documentation_repository.dart';

class DocumentationStore extends ChangeNotifier {
  DocumentationStore({DocumentationRepository? repository})
      : _repository = repository ?? LocalDocumentationRepository();

  final DocumentationRepository _repository;

  List<DocumentationEntry> entries = [];
  bool isLoading = true;

  Future<void> init() async {
    try {
      entries = await _repository.loadEntries();
    } catch (_) {
      entries = [];
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> addEntry(DocumentationEntry entry) async {
    entries.add(entry);
    notifyListeners();
    await _repository.saveEntries(entries);
  }

  Future<void> removeEntry(String id) async {
    entries.removeWhere((e) => e.id == id);
    notifyListeners();
    await _repository.saveEntries(entries);
  }
}
