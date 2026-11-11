import 'package:flutter_test/flutter_test.dart';

import 'package:baustelli/models/app_settings.dart';
import 'package:baustelli/models/project.dart';
import 'package:baustelli/repositories/project_repository.dart';
import 'package:baustelli/repositories/settings_repository.dart';
import 'package:baustelli/state/project_store.dart';
import 'package:baustelli/state/settings_store.dart';

// Regressionstest für den beim Bau des Update-Systems entdeckten Bug: ein
// Lesefehler beim Start (kaputtes JSON, Bug in einem künftigen
// Migrationsschritt, ...) darf NIE dazu führen, dass die App stillschweigend
// auf eine leere/Standard-Fassung zurückfällt und diese dann beim nächsten
// Save über die echten, noch intakten gespeicherten Daten schreibt.

class _ThrowingProjectRepository implements ProjectRepository {
  int saveCalls = 0;

  @override
  Future<List<Project>> loadProjects() async =>
      throw Exception('kaputtes JSON');

  @override
  Future<void> saveProjects(List<Project> projects) async {
    saveCalls++;
  }
}

class _ThrowingSettingsRepository implements SettingsRepository {
  int saveCalls = 0;

  @override
  Future<AppSettings> loadSettings() async =>
      throw Exception('kaputtes JSON');

  @override
  Future<void> saveSettings(AppSettings settings) async {
    saveCalls++;
  }
}

void main() {
  test('ProjectStore: Ladefehler setzt loadFailed und verhindert jedes '
      'spätere Speichern, statt die echten Daten mit einer leeren Liste zu '
      'überschreiben', () async {
    final repo = _ThrowingProjectRepository();
    final store = ProjectStore(repository: repo);

    await store.init();

    expect(store.loadFailed, isTrue);
    expect(store.projects, isEmpty);

    // Eine normale Aktion, die sonst persistieren würde - darf im
    // loadFailed-Zustand NICHT beim Repository ankommen.
    await store.addProject('Testprojekt');

    expect(repo.saveCalls, 0);
  });

  test('ProjectStore: removeProject() umgeht _persist() mit einem eigenen '
      'Repository-Aufruf - auch dieser muss im loadFailed-Zustand '
      'blockiert bleiben (Regressionstest für einen zunächst übersehenen '
      'Bypass)', () async {
    final repo = _ThrowingProjectRepository();
    final store = ProjectStore(repository: repo);
    // loadFailed künstlich mit einer nicht-leeren Projektliste kombinieren
    // (normalerweise unmöglich über init(), aber genau diese Kombination
    // ist der Fall, den die direkten Repository-Aufrufe fälschlich für
    // ausgeschlossen hielten) - prüft den Schutz unabhängig von der
    // Randbedingung "projects ist ohnehin leer".
    store.loadFailed = true;
    store.projects.add(Project('p1', 'Soll nicht gespeichert werden'));

    await store.removeProject('p1');

    expect(repo.saveCalls, 0);
  });

  test('SettingsStore: Ladefehler setzt loadFailed und verhindert jedes '
      'spätere Speichern', () async {
    final repo = _ThrowingSettingsRepository();
    final store = SettingsStore(repository: repo);

    await store.init();

    expect(store.loadFailed, isTrue);

    await store.setJumpToLastProject(true);

    expect(repo.saveCalls, 0);
  });
}
