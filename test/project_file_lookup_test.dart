import 'package:flutter_test/flutter_test.dart';

import 'package:baustelli/models/gewerk.dart';
import 'package:baustelli/models/modules/file_module.dart';
import 'package:baustelli/models/project.dart';
import 'package:baustelli/utils/project_file_lookup.dart';

void main() {
  group('findFileEntry / allFileEntries', () {
    late Project project;

    setUp(() {
      project = Project('p1', 'Testprojekt', gewerke: [
        Gewerk('g1', 'Elektrik', modules: [
          FileModule('m1', entries: [
            FileEntry(id: 'f1', name: 'Grundriss', fileType: 'pdf'),
          ]),
        ]),
        Gewerk('g2', 'Sanitär', modules: [
          FileModule('m2', entries: [
            FileEntry(id: 'f2', name: 'Baustelle', fileType: 'photo'),
          ]),
        ]),
      ]);
    });

    test('findFileEntry findet eine Datei projektweit, auch in einem anderen Gewerk', () {
      final location = findFileEntry(project, 'f2');
      expect(location, isNotNull);
      expect(location!.gewerk.id, 'g2');
      expect(location.module.id, 'm2');
      expect(location.entry.name, 'Baustelle');
    });

    test('findFileEntry liefert null für unbekannte ID statt zu werfen', () {
      expect(findFileEntry(project, 'unbekannt'), isNull);
    });

    test('allFileEntries listet Dateien aus allen Gewerken', () {
      final all = allFileEntries(project);
      expect(all.map((f) => f.entry.id), containsAll(['f1', 'f2']));
      expect(all, hasLength(2));
    });
  });
}
