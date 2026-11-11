import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../services/update_check_service.dart';
import '../state/project_store.dart';
import '../state/settings_store.dart';
import '../utils/file_export.dart';
import '../utils/id_generator.dart';
import '../utils/profile_prompt.dart';
import '../widgets/app_bar.dart';
import '../widgets/dialogs/new_project_dialog.dart';
import '../widgets/project_card.dart';
import '../widgets/update_dialog.dart';
import 'documentation_screen.dart';
import 'gewerke_screen.dart';
import 'join_project_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  // ✅ verhindert, dass der Auto-Sprung bei jedem Rebuild erneut ausgelöst wird
  bool _autoJumpChecked = false;

  @override
  void initState() {
    super.initState();
    // ✅ Still im Hintergrund, blockiert den Start nicht - zeigt nur bei
    // tatsächlich gefundenem Update einen Hinweis (siehe
    // UpdateCheckService: höchstens alle 24h ein echter Request, Fehler
    // werden intern geschluckt statt hier anzukommen).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final update = await UpdateCheckService.instance.checkForUpdate();
      if (update != null && mounted) {
        showUpdateAvailableDialog(context, update);
      }
    });
  }

  void _openProject(BuildContext context, String projectId) {
    context.read<SettingsStore>().setLastProject(projectId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GewerkeScreen(projectId: projectId),
      ),
    );
  }

  Future<void> _importProject(BuildContext context) async {
    final content = await importTextFile();
    if (content == null || !context.mounted) return;

    final store = context.read<ProjectStore>();
    try {
      final project = Project.fromMap(
        jsonDecode(content) as Map<String, dynamic>,
      );
      // Neue ID, damit ein Import nie mit einem vorhandenen Projekt kollidiert.
      project.id = newId();
      await store.importProject(project);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Projekt "${project.name}" importiert')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Import fehlgeschlagen – ungültige Datei")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProjectStore>();
    final settingsStore = context.watch<SettingsStore>();

    if (!_autoJumpChecked &&
        !store.isLoading &&
        !store.loadFailed &&
        !settingsStore.isLoading) {
      _autoJumpChecked = true;
      final lastId = settingsStore.settings.lastProjectId;
      final shouldJump = settingsStore.settings.jumpToLastProject &&
          lastId != null &&
          store.projects.any((p) => p.id == lastId);
      if (shouldJump) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openProject(context, lastId);
        });
      }
    }

    return Scaffold(
      appBar: buildAppBar(
        "Erwinator",
        context,
        false,
        onCreate:
            store.loadFailed ? null : () => showNewProjectDialog(context),
        createTooltip: "Neues Projekt",
      ),
      body: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : store.loadFailed
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          "Deine gespeicherten Daten konnten nicht geladen "
                          "werden. Nichts wurde gelöscht — deine Projekte "
                          "sind weiterhin auf dem Gerät vorhanden, konnten "
                          "nur nicht gelesen werden. Es wird solange auch "
                          "nichts mehr gespeichert, um sie nicht zu "
                          "überschreiben.",
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Bitte Fehlerprotokoll prüfen oder Support "
                          "kontaktieren.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...store.projects.map((project) {
                  return GestureDetector(
                    onTap: () => _openProject(context, project.id),
                    child: projectCard(
                      name: project.name,
                      address: project.address,
                      update: "",
                    ),
                  );
                }),
                if (store.projects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        "Noch keine Projekte – oben links anlegen",
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _importProject(context),
                    icon: const Icon(Icons.file_open),
                    label: const Text("Projekt importieren"),
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DocumentationScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.folder_special_outlined),
                    label: const Text("Dokumentation"),
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      final proceed = await ensureProfileForSharing(context);
                      if (!proceed || !context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const JoinProjectScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.group_add),
                    label: const Text("Projekt beitreten"),
                  ),
                ),
              ],
            ),
    );
  }
}
