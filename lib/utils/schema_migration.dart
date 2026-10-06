// Versionierungs-Infrastruktur für lokal gespeicherte Daten
// (SharedPreferences). Jede gespeicherte JSON-Struktur wird ab jetzt in
// einen Umschlag {"schemaVersion": N, "data": ...} gepackt statt wie bisher
// als blankes Array/Objekt abgelegt. So kann künftig sicher zwischen
// Versionen migriert werden, statt sich nur auf `??`-Defaults in den
// `fromMap()`-Factories zu verlassen.
//
// ⚠️ WICHTIG für künftige Breaking Changes an einem Modell (Feld umbenannt/
// entfernt/umgedeutet in toMap()/fromMap()): hier eine neue Migrationsstufe
// in die passende Liste (projectMigrationSteps/settingsMigrationSteps)
// ergänzen UND die jeweilige currentSchemaVersion-Konstante erhöhen. Nicht
// einfach nur fromMap()-Defaults anpassen und hoffen, dass es reicht - alte,
// bereits gespeicherte Daten durchlaufen sonst nie den nötigen
// Übersetzungsschritt.

typedef MigrationStep = dynamic Function(dynamic data);

// Normalisiert rohes, bereits per jsonDecode gewonnenes JSON auf die
// aktuelle Version: erkennt das alte, unverpackte Format (bare List/Map
// ohne "schemaVersion"-Key) als implizite Version 1 und wendet alle
// nötigen Migrationsschritte sequenziell bis currentVersion an. Gibt die
// (migrierten) Nutzdaten zurück, bereit für die bestehenden
// fromMap()-Factories.
dynamic migrate({
  required dynamic rawDecoded,
  required int currentVersion,
  required List<MigrationStep> steps,
}) {
  int version;
  dynamic data;
  if (rawDecoded is Map<String, dynamic> &&
      rawDecoded.containsKey('schemaVersion')) {
    version = rawDecoded['schemaVersion'] as int;
    data = rawDecoded['data'];
  } else {
    // Legacy: unverpacktes bare Array/Objekt -> implizit Version 1 (vor
    // Einführung des Umschlags).
    version = 1;
    data = rawDecoded;
  }
  for (var v = version; v < currentVersion; v++) {
    data = steps[v - 1](data);
  }
  return data;
}

// Verpackt Nutzdaten für den Save-Pfad in den aktuellen Umschlag.
Map<String, dynamic> wrap({required int version, required dynamic data}) =>
    {'schemaVersion': version, 'data': data};

// --- Projekte (LocalProjectRepository) ---
const currentProjectSchemaVersion = 2;
final List<MigrationStep> projectMigrationSteps = [
  // v1 (legacy, bare Array ohne Umschlag) -> v2 (führt nur den Umschlag
  // selbst ein, keine Datenform-Änderung). Künftige Breaking Changes an
  // Project/Gewerk/... bekommen hier einen echten Migrationsschritt.
  (data) => data,
];

// --- App-Einstellungen (LocalSettingsRepository) ---
const currentSettingsSchemaVersion = 2;
final List<MigrationStep> settingsMigrationSteps = [
  // v1 (legacy, bare Objekt ohne Umschlag) -> v2 (führt nur den Umschlag
  // selbst ein, keine Datenform-Änderung).
  (data) => data,
];
