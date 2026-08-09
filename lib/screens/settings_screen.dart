import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/settings_store.dart';
import '../utils/kurzzeichen.dart';
import '../widgets/app_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _googleController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsStore>().settings;
    _nameController = TextEditingController(text: settings.userName);
    _googleController =
        TextEditingController(text: settings.googleAccountEmail);
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _googleController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    context.read<SettingsStore>().updateProfile(
          userName: _nameController.text.trim(),
          googleAccountEmail: _googleController.text.trim(),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Gespeichert")),
    );
  }

  void _showInviteDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Nutzer zum Teilen einladen"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name *"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration:
                    const InputDecoration(labelText: "E-Mail-Adresse"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                context.read<SettingsStore>().addInvitedUser(
                      name: nameController.text.trim(),
                      email: emailController.text.trim(),
                    );
                Navigator.pop(dialogContext);
              },
              child: const Text("Einladen"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>().settings;
    final kurzzeichenPreview = _nameController.text.trim().isEmpty
        ? '—'
        : generateKurzzeichen(
            _nameController.text.trim(),
            settings.invitedUsers.map((u) => u.kurzzeichen),
          );

    return Scaffold(
      appBar: buildAppBar("Optionen", context, true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Beim Start ins letzte Projekt springen"),
            value: settings.jumpToLastProject,
            onChanged: (value) {
              context
                  .read<SettingsStore>()
                  .setJumpToLastProject(value ?? false);
            },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Ersteller/Bearbeiter anzeigen"),
            subtitle: const Text(
              "Kleines (i)-Symbol in den Modulen zeigt, wer etwas erstellt, "
              "bearbeitet oder abgehakt hat.",
            ),
            value: settings.showAuthorInfo,
            onChanged: (value) {
              context.read<SettingsStore>().setShowAuthorInfo(value ?? true);
            },
          ),
          const Divider(height: 32),

          const Text(
            "Benutzerinfos",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Werden für Historys verwendet (wer hat was erstellt/geändert).",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "Name"),
          ),
          const SizedBox(height: 10),
          Text(
            "Namenskürzel (automatisch): $kurzzeichenPreview",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _googleController,
            decoration: const InputDecoration(
              labelText: "Verknüpftes Google-Profil (für Kalender)",
              helperText:
                  "Wird nur gespeichert – echte Anmeldung folgt später.",
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _saveProfile,
              child: const Text("Speichern"),
            ),
          ),
          const Divider(height: 32),

          const Text(
            "Teilen",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Eingeladene Nutzer werden nur lokal gemerkt – ein echter Versand ist noch nicht angebunden.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          if (settings.invitedUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text("Noch niemand eingeladen"),
            ),
          ...settings.invitedUsers.map((user) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                child: Text(
                  user.kurzzeichen,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              title: Text(user.name),
              subtitle: user.email.isEmpty ? null : Text(user.email),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    context.read<SettingsStore>().removeInvitedUser(user.id),
              ),
            );
          }),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showInviteDialog,
            icon: const Icon(Icons.person_add_alt),
            label: const Text("Nutzer einladen"),
          ),
        ],
      ),
    );
  }
}
