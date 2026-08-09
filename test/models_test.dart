import 'package:flutter_test/flutter_test.dart';

import 'package:baustelli/models/app_settings.dart';
import 'package:baustelli/models/audit_entry.dart';
import 'package:baustelli/models/checklist_item.dart';
import 'package:baustelli/models/gewerk.dart';
import 'package:baustelli/models/image_annotation.dart';
import 'package:baustelli/models/modules/contact_module.dart';
import 'package:baustelli/models/helper_demand.dart';
import 'package:baustelli/models/modules/file_module.dart';
import 'package:baustelli/models/modules/todo_module.dart';
import 'package:baustelli/models/project.dart';
import 'package:baustelli/models/project_member.dart';
import 'package:baustelli/models/task.dart';
import 'package:baustelli/models/team_member.dart';
import 'package:baustelli/utils/kurzzeichen.dart';

void main() {
  group('Model round-trips (toMap -> fromMap -> toMap)', () {
    test('ChecklistItem', () {
      final item = ChecklistItem('Steckdosen prüfen', isDone: true);
      final restored = ChecklistItem.fromMap(item.toMap());
      expect(restored.toMap(), item.toMap());
    });

    test('AuditEntry', () {
      final entry = AuditEntry(
        kurzzeichen: 'MAMU',
        action: 'erstellt',
        timestamp: DateTime(2026, 3, 1, 9, 30),
      );
      final restored = AuditEntry.fromMap(entry.toMap());
      expect(restored.toMap(), entry.toMap());
    });

    test('TeamMember', () {
      final member = TeamMember(
        id: 'u1',
        name: 'Max Mustermann',
        email: 'max@example.com',
        kurzzeichen: 'MAMU',
      );
      final restored = TeamMember.fromMap(member.toMap());
      expect(restored.toMap(), member.toMap());
    });

    test('AppSettings mit eingeladenen Nutzern', () {
      final settings = AppSettings(
        userName: 'Max Mustermann',
        userInitials: 'MAMU',
        showAuthorInfo: false,
        invitedUsers: [
          TeamMember(id: 'u1', name: 'Anna Bauer', kurzzeichen: 'ANBA'),
        ],
      );
      final restored = AppSettings.fromMap(settings.toMap());
      expect(restored.toMap(), settings.toMap());
    });

    test('Task ohne Fälligkeitsdatum', () {
      final task = Task('t1', 'Kabel verlegen', createdBy: 'User');
      final restored = Task.fromMap(task.toMap());
      expect(restored.toMap(), task.toMap());
    });

    test('Task mit Fälligkeitsdatum, Checkliste und Verlauf', () {
      final task = Task(
        't2',
        'Steckdosen setzen',
        description: 'Im Wohnzimmer',
        isHighPriority: true,
        dueDate: DateTime(2026, 1, 1),
        checklist: [ChecklistItem('Material bestellt')],
        createdBy: 'MAMU',
        history: [
          AuditEntry(
              kurzzeichen: 'MAMU',
              action: 'erstellt',
              timestamp: DateTime(2026, 1, 1)),
          AuditEntry(
              kurzzeichen: 'ANBA',
              action: 'abgehakt',
              timestamp: DateTime(2026, 1, 2)),
        ],
      );
      final restored = Task.fromMap(task.toMap());
      expect(restored.toMap(), task.toMap());
    });

    test('ContactModule mit Verlauf', () {
      final module = ContactModule(
        'm1',
        label: 'Elektriker Müller',
        name: 'Max Elektriker',
        phone: '0123456789',
        history: [
          AuditEntry(
              kurzzeichen: 'MAMU',
              action: 'bearbeitet',
              timestamp: DateTime(2026, 1, 3)),
        ],
      );
      final restored = ContactModule.fromMap(module.toMap());
      expect(restored.toMap(), module.toMap());
    });

    test('TodoModule mit mehreren Tasks', () {
      final module = TodoModule('m2', label: 'Elektro-Aufgaben', tasks: [
        Task('t1', 'A', createdBy: 'User'),
        Task('t2', 'B', createdBy: 'User', dueDate: DateTime(2026, 2, 2)),
      ]);
      final restored = TodoModule.fromMap(module.toMap());
      expect(restored.toMap(), module.toMap());
    });

    test('FileModule mit PDF-Eintrag, mehreren Versionen und Verlauf', () {
      final module = FileModule('m3', label: 'Angebote', entries: [
        FileEntry(
          id: 'f1',
          name: 'Angebot.pdf',
          fileType: 'pdf',
          versions: [
            FileVersion(
                id: 'v1',
                label: 'v1',
                createdBy: 'MAMU',
                createdAt: DateTime(2026, 1, 1)),
            FileVersion(
                id: 'v2',
                label: 'v2 - korrigiert',
                createdBy: 'ANBA',
                createdAt: DateTime(2026, 1, 5)),
          ],
          history: [
            AuditEntry(
                kurzzeichen: 'MAMU',
                action: 'hochgeladen',
                timestamp: DateTime(2026, 1, 1)),
            AuditEntry(
                kurzzeichen: 'ANBA',
                action: 'neue Version hochgeladen (v2 - korrigiert)',
                timestamp: DateTime(2026, 1, 5)),
          ],
        ),
      ]);
      final restored = FileModule.fromMap(module.toMap());
      expect(restored.toMap(), module.toMap());
    });

    test('ImageAnnotation Kommentar und Messung', () {
      final comment = ImageAnnotation(
        id: 'a1',
        type: ImageAnnotation.typeComment,
        x: 0.42,
        y: 0.17,
        text: 'Riss im Putz',
        createdBy: 'MAMU',
        createdAt: DateTime(2026, 4, 1, 10, 0),
      );
      final restoredComment = ImageAnnotation.fromMap(comment.toMap());
      expect(restoredComment.toMap(), comment.toMap());

      final measurement = ImageAnnotation(
        id: 'a2',
        type: ImageAnnotation.typeMeasurement,
        x: 0.1,
        y: 0.2,
        x2: 0.6,
        y2: 0.25,
        text: '1,3 m',
        createdBy: 'ANBA',
        createdAt: DateTime(2026, 4, 1, 10, 5),
      );
      final restoredMeasurement = ImageAnnotation.fromMap(measurement.toMap());
      expect(restoredMeasurement.toMap(), measurement.toMap());
    });

    test('FileEntry (Foto) mit lokalem Pfad und Markierungen', () {
      final entry = FileEntry(
        id: 'f2',
        name: 'Baustelle Nordseite',
        fileType: 'photo',
        localImagePath: '/data/baustelli_photos/f2.jpg',
        versions: [
          FileVersion(id: 'v1', label: '1.0', createdBy: 'MAMU'),
        ],
        annotations: [
          ImageAnnotation(
            id: 'a1',
            type: ImageAnnotation.typeComment,
            x: 0.3,
            y: 0.4,
            text: 'Hier fehlt die Dämmung',
            createdBy: 'MAMU',
          ),
          ImageAnnotation(
            id: 'a2',
            type: ImageAnnotation.typeMeasurement,
            x: 0.1,
            y: 0.1,
            x2: 0.5,
            y2: 0.1,
            text: '1,3 m',
            createdBy: 'MAMU',
          ),
        ],
      );
      final restored = FileEntry.fromMap(entry.toMap());
      expect(restored.toMap(), entry.toMap());
    });

    test('HelperDemand mit Zusagen und Verlauf', () {
      final demand = HelperDemand(
        id: 'd1',
        date: DateTime(2026, 3, 2),
        neededCount: 3,
        note: 'Betonieren',
        signups: [
          HelperSignup(
              id: 's1', name: 'Anna', startTime: '08:00', endTime: '12:00'),
          HelperSignup(id: 's2', name: 'Ben'),
        ],
        history: [
          AuditEntry(
              kurzzeichen: 'MAMU',
              action: 'Bedarf eingetragen',
              timestamp: DateTime(2026, 2, 20)),
          AuditEntry(
              kurzzeichen: 'MAMU',
              action: 'Helfer eingetragen: Anna',
              timestamp: DateTime(2026, 2, 21)),
        ],
      );
      final restored = HelperDemand.fromMap(demand.toMap());
      expect(restored.toMap(), demand.toMap());
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

    test('Project mit Projektart und Helferbedarf', () {
      final project = Project(
        'p2',
        'Neubau Musterweg',
        projectType: 'neubau',
        gewerke: [Gewerk('g1', 'Architekt')],
        helperDemands: [
          HelperDemand(
            id: 'd1',
            date: DateTime(2026, 4, 1),
            neededCount: 2,
            signups: [HelperSignup(id: 's1', name: 'Anna')],
          ),
        ],
      );
      final restored = Project.fromMap(project.toMap());
      expect(restored.toMap(), project.toMap());
    });

    test('Project mit sharedId (geteiltes Projekt)', () {
      final project = Project(
        'p3',
        'Geteiltes Projekt',
        sharedId: 'cloud-uuid-123',
      );
      final restored = Project.fromMap(project.toMap());
      expect(restored.toMap(), project.toMap());
      expect(restored.sharedId, 'cloud-uuid-123');
    });
  });

  group('ProjectMember', () {
    test('fromMap liest eine Supabase-Zeile korrekt', () {
      final member = ProjectMember.fromMap({
        'id': 'm1',
        'project_id': 'p1',
        'user_id': 'u1',
        'display_name': 'Anna Bauer',
        'kurzzeichen': 'ANBA',
        'status': 'pending',
        'invited_at': '2026-05-01T10:00:00.000Z',
      });
      expect(member.id, 'm1');
      expect(member.projectId, 'p1');
      expect(member.userId, 'u1');
      expect(member.displayName, 'Anna Bauer');
      expect(member.kurzzeichen, 'ANBA');
      expect(member.status, ProjectMember.statusPending);
    });
  });

  group('generateKurzzeichen', () {
    test('nimmt 2 Buchstaben Vorname + 2 Buchstaben Nachname', () {
      expect(generateKurzzeichen('Max Mustermann', []), 'MAMU');
    });

    test('füllt einteilige Namen mit X auf', () {
      expect(generateKurzzeichen('Anna', []), 'ANXX');
    });

    test('hängt bei Kollision eine Ziffer an', () {
      expect(generateKurzzeichen('Max Mustermann', ['MAMU']), 'MAMU2');
    });

    test('erhöht die Ziffer, bis ein freies Kürzel gefunden ist', () {
      expect(
        generateKurzzeichen('Max Mustermann', ['MAMU', 'MAMU2', 'MAMU3']),
        'MAMU4',
      );
    });

    test('ignoriert Groß-/Kleinschreibung beim Kollisionsvergleich', () {
      expect(generateKurzzeichen('Max Mustermann', ['mamu']), 'MAMU2');
    });
  });
}
