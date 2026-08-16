import 'package:flutter_test/flutter_test.dart';

import 'package:baustelli/models/finance_entry.dart';
import 'package:baustelli/models/gewerk.dart';
import 'package:baustelli/models/modules/contact_module.dart';
import 'package:baustelli/models/modules/file_module.dart';
import 'package:baustelli/models/modules/todo_module.dart';
import 'package:baustelli/models/presence_entry.dart';
import 'package:baustelli/models/project.dart';
import 'package:baustelli/models/task.dart';
import 'package:baustelli/models/time_tracking.dart';

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

    test(
        'onSitePresence: gleichzeitiges An-/Abmelden zweier Nutzer auf zwei Geräten bleibt für beide erhalten',
        () {
      final local = Project('p1', 'Testprojekt', onSitePresence: [
        PresenceEntry('Anna', updatedAt: DateTime(2026, 1, 1)),
      ]);
      final remote = Project.fromMap(local.toMap());

      // Lokal: Ben meldet sich an (Anna bleibt unverändert).
      local.onSitePresence.add(PresenceEntry('Ben', updatedAt: DateTime(2026, 1, 2)));

      // Remote: Anna meldet sich ab (Ben ist dort noch nicht bekannt).
      remote.onSitePresence.removeWhere((e) => e.person == 'Anna');
      remote.deletedIds['presence:Anna'] = DateTime(2026, 1, 3);

      final merged = local.mergeFrom(remote);
      // Mit einem kompletten Listen-Merge (vorheriges Verhalten) hätte die
      // neuere Seite (remote) gewonnen und Bens Anmeldung wäre verloren
      // gegangen. Feldweise bleiben beide unabhängigen Änderungen erhalten.
      expect(merged.onSitePresence.map((e) => e.person), ['Ben']);
    });

    test(
        'onSitePresence: erneutes Anmelden NACH einer Abmeldung auf einem anderen Gerät gewinnt ("Edit schlägt Delete")',
        () {
      final local = Project('p1', 'Testprojekt', onSitePresence: [
        PresenceEntry('Anna', updatedAt: DateTime(2026, 1, 1)),
      ]);
      final remote = Project.fromMap(local.toMap());

      // Lokal: Anna abgemeldet.
      local.onSitePresence.removeWhere((e) => e.person == 'Anna');
      local.deletedIds['presence:Anna'] = DateTime(2026, 1, 2);

      // Remote: Anna NACH der Abmeldung wieder angemeldet.
      remote.onSitePresence.first.updatedAt = DateTime(2026, 1, 10);

      final merged = local.mergeFrom(remote);
      expect(merged.onSitePresence.map((e) => e.person), ['Anna']);
    });

    test(
        'WorkDayEntry.helperNames: ein auf einem Gerät entfernter Helfer bleibt entfernt, auch wenn die andere Seite nur die Stunden desselben Tages ändert',
        () {
      final entry = WorkDayEntry(
        id: 'day1',
        date: DateTime(2026, 3, 2),
        hours: 8,
        helperNames: [
          PresenceEntry('Anna', updatedAt: DateTime(2026, 3, 2)),
          PresenceEntry('Ben', updatedAt: DateTime(2026, 3, 2)),
        ],
        updatedAt: DateTime(2026, 3, 2),
      );
      final local = Project('p1', 'Testprojekt', workDayEntries: [entry]);
      final remote = Project.fromMap(local.toMap());

      // Lokal: Ben wird aus dem Tag entfernt (Tombstone + neuer Zeitstempel,
      // wie in ProjectStore.removeHelperSignup).
      final localEntry = local.workDayEntries.first;
      localEntry.helperNames.removeWhere((p) => p.person == 'Ben');
      local.deletedIds['helper:day1:Ben'] = DateTime(2026, 3, 3);
      localEntry.updatedAt = DateTime(2026, 3, 3);

      // Remote: nur die Stunden desselben Tages geändert, neuerer
      // Zeitstempel als lokal -> gewinnt beim Stunden-Feld.
      final remoteEntry = remote.workDayEntries.first;
      remoteEntry.hours = 6;
      remoteEntry.updatedAt = DateTime(2026, 3, 4);

      final merged = local.mergeFrom(remote);
      final mergedEntry = merged.workDayEntries.first;
      expect(mergedEntry.hours, 6); // remote gewinnt beim Stunden-Feld
      expect(mergedEntry.helperNames.map((p) => p.person), ['Anna']);
    });

    test(
        'financeEntries: zwei gleichzeitig auf unterschiedlichen Geräten erfasste Rechnungen bleiben beide erhalten',
        () {
      final local = Project('p1', 'Testprojekt', gewerke: [Gewerk('g1', 'Elektrik')]);
      final remote = Project.fromMap(local.toMap());

      local.financeEntries.add(FinanceEntry(
        id: 'f-local',
        gewerkId: 'g1',
        documentType: FinanceDocumentType.rechnung,
        amountGross: 500,
        createdBy: 'AA',
      ));
      remote.financeEntries.add(FinanceEntry(
        id: 'f-remote',
        gewerkId: 'g1',
        documentType: FinanceDocumentType.angebot,
        amountGross: 900,
        createdBy: 'BB',
      ));

      final merged = local.mergeFrom(remote);
      expect(merged.financeEntries.map((e) => e.id),
          containsAll(['f-local', 'f-remote']));
    });

    test('itemRefs: ein entfernter Datei-Verweis wird durch den Merge mit einer unveränderten anderen Seite nicht wiederhergestellt', () {
      final task = Task('t1', 'Loch zuschütten', createdBy: 'AA', itemRefs: ['f1']);
      final todoModule = TodoModule('m1', tasks: [task]);
      final local = Project('p1', 'Testprojekt', gewerke: [
        Gewerk('g1', 'Allgemein', modules: [todoModule]),
      ]);
      final remote = Project.fromMap(local.toMap());

      // Lokal: Verweis entfernt (wie ProjectStore.removeTaskItemRef: aus
      // der Liste UND als Tombstone).
      final localTask =
          (local.gewerke.first.modules.first as TodoModule).tasks.first;
      localTask.itemRefs.remove('f1');
      localTask.updatedAt = DateTime.now();
      local.deletedIds['itemRef:t1:f1'] = DateTime.now();

      // Remote: unverändert, hält noch die alte Verknüpfung.
      final merged = local.mergeFrom(remote);
      final mergedTask =
          (merged.gewerke.first.modules.first as TodoModule).tasks.first;
      expect(mergedTask.itemRefs, isEmpty);
    });

    test('financeEntries: ein gelöschter Eintrag bleibt gelöscht, wenn die andere Seite ihn unverändert lässt', () {
      final local = Project('p1', 'Testprojekt', financeEntries: [
        FinanceEntry(
          id: 'f1',
          gewerkId: 'g1',
          documentType: FinanceDocumentType.rechnung,
          amountGross: 500,
          createdBy: 'AA',
        ),
      ]);
      final remote = Project.fromMap(local.toMap());

      local.financeEntries.removeWhere((e) => e.id == 'f1');
      local.deletedIds['f1'] = DateTime.now();

      final merged = local.mergeFrom(remote);
      expect(merged.financeEntries, isEmpty);
    });
  });
}
