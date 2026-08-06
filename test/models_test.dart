import 'package:flutter_test/flutter_test.dart';

import 'package:baustelli/models/checklist_item.dart';
import 'package:baustelli/models/gewerk.dart';
import 'package:baustelli/models/modules/contact_module.dart';
import 'package:baustelli/models/modules/file_module.dart';
import 'package:baustelli/models/modules/todo_module.dart';
import 'package:baustelli/models/project.dart';
import 'package:baustelli/models/task.dart';

void main() {
  group('Model round-trips (toMap -> fromMap -> toMap)', () {
    test('ChecklistItem', () {
      final item = ChecklistItem('Steckdosen prüfen', isDone: true);
      final restored = ChecklistItem.fromMap(item.toMap());
      expect(restored.toMap(), item.toMap());
    });

    test('Task ohne Fälligkeitsdatum', () {
      final task = Task('t1', 'Kabel verlegen', createdBy: 'User');
      final restored = Task.fromMap(task.toMap());
      expect(restored.toMap(), task.toMap());
    });

    test('Task mit Fälligkeitsdatum und Checkliste', () {
      final task = Task(
        't2',
        'Steckdosen setzen',
        description: 'Im Wohnzimmer',
        isHighPriority: true,
        dueDate: DateTime(2026, 1, 1),
        checklist: [ChecklistItem('Material bestellt')],
        createdBy: 'User',
      );
      final restored = Task.fromMap(task.toMap());
      expect(restored.toMap(), task.toMap());
    });

    test('ContactModule', () {
      final module =
          ContactModule('m1', name: 'Max Elektriker', phone: '0123456789');
      final restored = ContactModule.fromMap(module.toMap());
      expect(restored.toMap(), module.toMap());
    });

    test('TodoModule mit mehreren Tasks', () {
      final module = TodoModule('m2', tasks: [
        Task('t1', 'A', createdBy: 'User'),
        Task('t2', 'B', createdBy: 'User', dueDate: DateTime(2026, 2, 2)),
      ]);
      final restored = TodoModule.fromMap(module.toMap());
      expect(restored.toMap(), module.toMap());
    });

    test('FileModule mit PDF-Eintrag und mehreren Versionen', () {
      final module = FileModule('m3', entries: [
        FileEntry(
          id: 'f1',
          name: 'Angebot.pdf',
          fileType: 'pdf',
          versions: [
            FileVersion(
                id: 'v1', label: 'v1', createdAt: DateTime(2026, 1, 1)),
            FileVersion(
                id: 'v2',
                label: 'v2 - korrigiert',
                createdAt: DateTime(2026, 1, 5)),
          ],
        ),
      ]);
      final restored = FileModule.fromMap(module.toMap());
      expect(restored.toMap(), module.toMap());
    });

    test('Gewerk mit gemischten Modultypen', () {
      final gewerk = Gewerk('g1', 'Elektrik', modules: [
        ContactModule('m1', name: 'Elektriker Müller', phone: '0111'),
        TodoModule('m2', tasks: [
          Task('t1', 'Sicherungskasten', createdBy: 'User'),
        ]),
      ]);
      final restored = Gewerk.fromMap(gewerk.toMap());
      expect(restored.toMap(), gewerk.toMap());
    });

    test('Project', () {
      final project = Project(
        'p1',
        'Mein Haus',
        address: 'Musterstraße 12',
        gewerke: [Gewerk('g1', 'Rohbau')],
      );
      final restored = Project.fromMap(project.toMap());
      expect(restored.toMap(), project.toMap());
    });
  });
}
