import 'package:flutter_test/flutter_test.dart';

import 'package:baustelli/models/gewerk.dart';
import 'package:baustelli/models/modules/contact_module.dart';
import 'package:baustelli/models/modules/file_module.dart';
import 'package:baustelli/models/modules/todo_module.dart';
import 'package:baustelli/models/project.dart';
import 'package:baustelli/models/task.dart';

// Sync-Merge (Option C, siehe lib/utils/id_merge.dart und
// Project.mergeFrom): deckt genau die Fälle ab, die beim bisherigen
// "ganzes Projekt ersetzen"-Sync Daten verloren hätten.
void main() {
  group('Project.mergeFrom', () {
    test('zwei gleichzeitig auf unterschiedlichen Geräten angelegte Aufgaben bleiben beide erhalten', () {
      final todoModule = TodoModule('m1');
      final local = Project('p1', 'Testprojekt', gewerke: [
        Gewerk('g1', 'Allgemein', modules: [todoModule]),
      ]);
      final remote = Project.fromMap(local.toMap());

      (local.gewerke.first.modules.first as TodoModule).tasks.add(
            Task('t-local', 'Lokal angelegt', createdBy: 'AA'),
          );
      (remote.gewerke.first.modules.first as TodoModule).tasks.add(
            Task('t-remote', 'Remote angelegt', createdBy: 'BB'),
          );

      final merged = local.mergeFrom(remote);
      final tasks =
          (merged.gewerke.first.modules.first as TodoModule).tasks;
      expect(tasks.map((t) => t.id), containsAll(['t-local', 't-remote']));
      expect(tasks, hasLength(2));
    });

    test('bei gleichzeitiger Bearbeitung derselben Aufgabe gewinnt die neuere, aber der Verlauf beider Seiten bleibt', () {
      final task = Task('t1', 'Ursprung',
          createdBy: 'AA', updatedAt: DateTime(2026, 1, 1));
      final todoModule = TodoModule('m1', tasks: [task]);
      final local = Project('p1', 'Testprojekt', gewerke: [
        Gewerk('g1', 'Allgemein', modules: [todoModule]),
      ]);
      final remote = Project.fromMap(local.toMap());

      // Lokal: Status geändert, älterer Zeitstempel.
      final localTask =
          (local.gewerke.first.modules.first as TodoModule).tasks.first;
      localTask.status = 'teilweise';
      localTask.updatedAt = DateTime(2026, 1, 2);

      // Remote: Name geändert, neuerer Zeitstempel -> sollte gewinnen.
      final remoteTask =
          (remote.gewerke.first.modules.first as TodoModule).tasks.first;
      remoteTask.name = 'Remote-Name';
      remoteTask.updatedAt = DateTime(2026, 1, 3);

      final merged = local.mergeFrom(remote);
      final mergedTask =
          (merged.gewerke.first.modules.first as TodoModule).tasks.first;
      expect(mergedTask.name, 'Remote-Name');
      expect(mergedTask.status, 'offen'); // remote's (unveränderter) Status gewinnt mit
    });

    test('Löschen eines Gewerks wird NICHT durch eine spätere Bearbeitung auf der anderen Seite rückgängig gemacht, wenn die Bearbeitung VOR der Löschung war', () {
      final gewerk = Gewerk('g1', 'Elektrik', updatedAt: DateTime(2026, 1, 1));
      final local = Project('p1', 'Testprojekt', gewerke: [gewerk]);
      final remote = Project.fromMap(local.toMap());

      // Lokal: Gewerk gelöscht (Tombstone NACH der Remote-Bearbeitung).
      local.gewerke.removeWhere((g) => g.id == 'g1');
      local.deletedIds['g1'] = DateTime(2026, 1, 5);

      // Remote: Gewerk vor der Löschung umbenannt (älter als der Tombstone).
      remote.gewerke.first.name = 'Elektrik (alt)';
      remote.gewerke.first.updatedAt = DateTime(2026, 1, 3);

      final merged = local.mergeFrom(remote);
      expect(merged.gewerke, isEmpty);
    });

    test('"Edit schlägt Delete": eine Bearbeitung NACH der Löschung lässt das Gewerk wiederauferstehen', () {
      final gewerk = Gewerk('g1', 'Elektrik', updatedAt: DateTime(2026, 1, 1));
      final local = Project('p1', 'Testprojekt', gewerke: [gewerk]);
      final remote = Project.fromMap(local.toMap());

      // Lokal: Gewerk gelöscht.
      local.gewerke.removeWhere((g) => g.id == 'g1');
      local.deletedIds['g1'] = DateTime(2026, 1, 2);

      // Remote: NACH der Löschung noch umbenannt (Kollege wusste nichts
      // von der Löschung).
      remote.gewerke.first.name = 'Elektrik (bearbeitet)';
      remote.gewerke.first.updatedAt = DateTime(2026, 1, 10);

      final merged = local.mergeFrom(remote);
      expect(merged.gewerke, hasLength(1));
      expect(merged.gewerke.first.name, 'Elektrik (bearbeitet)');
    });

    test('ein lokal gelöschter Kontakt bleibt gelöscht, wenn die andere Seite ihn unverändert lässt', () {
      final contactModule = ContactModule('m1', contacts: [
        ContactPerson(id: 'c1', name: 'Max Mustermann'),
      ]);
      final local = Project('p1', 'Testprojekt', gewerke: [
        Gewerk('g1', 'Allgemein', modules: [contactModule]),
      ]);
      final remote = Project.fromMap(local.toMap());

      local.gewerke.first.modules
          .whereType<ContactModule>()
          .first
          .contacts
          .removeWhere((c) => c.id == 'c1');
      local.deletedIds['c1'] = DateTime.now();

      final merged = local.mergeFrom(remote);
      final contacts =
          (merged.gewerke.first.modules.first as ContactModule).contacts;
      expect(contacts, isEmpty);
    });

    test('localImagePath eines Fotos bleibt immer der lokale Wert, nie der der anderen Seite', () {
      final entry = FileEntry(
        id: 'f1',
        name: 'Baustelle',
        fileType: 'photo',
        localImagePath: '/local/path.jpg',
      );
      final fileModule = FileModule('m1', entries: [entry]);
      final local = Project('p1', 'Testprojekt', gewerke: [
        Gewerk('g1', 'Allgemein', modules: [fileModule]),
      ]);
      final remote = Project.fromMap(local.toMap());
      // Remote-Gerät hat den Pfad nie gesetzt (z.B. Web) oder einen
      // eigenen anderen lokalen Pfad.
      (remote.gewerke.first.modules.first as FileModule)
          .entries
          .first
          .localImagePath = null;

      final merged = local.mergeFrom(remote);
      final mergedEntry =
          (merged.gewerke.first.modules.first as FileModule).entries.first;
      expect(mergedEntry.localImagePath, '/local/path.jpg');
    });

    test('neu hinzugefügte Datei-Version geht beim Merge nicht verloren', () {
      final entry = FileEntry(id: 'f1', name: 'Angebot', fileType: 'pdf',
          versions: [FileVersion(id: 'v1', label: '1.0')]);
      final fileModule = FileModule('m1', entries: [entry]);
      final local = Project('p1', 'Testprojekt', gewerke: [
        Gewerk('g1', 'Allgemein', modules: [fileModule]),
      ]);
      final remote = Project.fromMap(local.toMap());

      (remote.gewerke.first.modules.first as FileModule)
          .entries
          .first
          .versions
          .add(FileVersion(id: 'v2', label: '1.1'));

      final merged = local.mergeFrom(remote);
      final versions =
          (merged.gewerke.first.modules.first as FileModule).entries.first.versions;
      expect(versions.map((v) => v.id), containsAll(['v1', 'v2']));
    });
  });
}
