import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/modules/contact_module.dart';
import '../../state/project_store.dart';
import '../../state/settings_store.dart';
import '../../utils/name_capitalization.dart';
import '../audit_info_icon.dart';
import 'module_card.dart';

class ContactModuleWidget extends StatelessWidget {
  final String projectId;
  final String gewerkId;
  final ContactModule module;

  const ContactModuleWidget({
    super.key,
    required this.projectId,
    required this.gewerkId,
    required this.module,
  });

  // ✅ Regelfall: Person(en) direkt aus den Telefonkontakten übernehmen.
  Future<void> _pickFromContacts(BuildContext context) async {
    final store = context.read<ProjectStore>();
    final actor = context.read<SettingsStore>().currentUserKurzzeichen;
    try {
      if (!await FlutterContacts.permissions.has(PermissionType.read)) {
        final status =
            await FlutterContacts.permissions.request(PermissionType.read);
        if (status != PermissionStatus.granted &&
            status != PermissionStatus.limited) {
          if (!context.mounted) return;
          final permanentlyDenied =
              status == PermissionStatus.permanentlyDenied ||
                  status == PermissionStatus.restricted;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                permanentlyDenied
                    ? "Kontakt-Zugriff wurde verweigert. Bitte in den "
                        "App-Einstellungen erlauben."
                    : "Zugriff auf Kontakte wurde nicht erlaubt.",
              ),
              action: permanentlyDenied
                  ? SnackBarAction(
                      label: "Einstellungen",
                      onPressed: FlutterContacts.permissions.openSettings,
                    )
                  : null,
            ),
          );
          return;
        }
      }
      final contact = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.phone},
      );
      if (contact == null || !context.mounted) return;
      final phone = contact.phones.isEmpty ? '' : contact.phones.first.number;
      store.addContactPerson(
        projectId,
        gewerkId,
        module.id,
        name: contact.displayName ?? '',
        phone: phone,
        actor: actor,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Kontaktauswahl ist auf dieser Plattform nicht verfügbar "
            "(nur Android/iOS).",
          ),
        ),
      );
    }
  }

  // Ausnahmefall: Person manuell erfassen, ohne Telefonkontakt.
  void _addManually(BuildContext context) {
    final store = context.read<ProjectStore>();
    final actor = context.read<SettingsStore>().currentUserKurzzeichen;
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Person manuell hinzufügen"),
          content: TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            inputFormatters: const [NameCapitalizationFormatter()],
            decoration: const InputDecoration(
              labelText: "Name *",
              helperText: "Mehrere Personen mit Komma trennen",
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () {
                final names = splitNames(nameController.text);
                if (names.isEmpty) return;
                for (final name in names) {
                  store.addContactPerson(
                    projectId,
                    gewerkId,
                    module.id,
                    name: name,
                    actor: actor,
                  );
                }
                Navigator.pop(dialogContext);
              },
              child: const Text("Hinzufügen"),
            ),
          ],
        );
      },
    ).then((_) => nameController.dispose());
  }

  Future<void> _call(BuildContext context, String phone) async {
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Anruf konnte nicht gestartet werden.")),
      );
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final launched = await launchUrl(Uri.parse('https://wa.me/$digits'));
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("WhatsApp konnte nicht geöffnet werden.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = context.watch<SettingsStore>().currentUserKurzzeichen;

    return ModuleCard(
      projectId: projectId,
      gewerkId: gewerkId,
      moduleId: module.id,
      icon: "📇",
      defaultTitle: "Kontakt",
      label: module.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _pickFromContacts(context),
                icon: const Icon(Icons.contacts, size: 18),
                label: const Text("Aus Kontakten importieren"),
              ),
              const Spacer(),
              AuditInfoIcon(history: module.history),
            ],
          ),
          if (module.contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                "Noch keine Personen hinterlegt.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...module.contacts.map(
              (person) => _ContactPersonTile(
                key: ValueKey(person.id),
                projectId: projectId,
                gewerkId: gewerkId,
                module: module,
                person: person,
                actor: actor,
                onCall: (phone) => _call(context, phone),
                onWhatsApp: (phone) => _openWhatsApp(context, phone),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addManually(context),
              icon: const Icon(Icons.person_add_alt, size: 16),
              label: const Text("Manuell hinzufügen (ohne Telefonkontakt)"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactPersonTile extends StatefulWidget {
  final String projectId;
  final String gewerkId;
  final ContactModule module;
  final ContactPerson person;
  final String actor;
  final void Function(String phone) onCall;
  final void Function(String phone) onWhatsApp;

  const _ContactPersonTile({
    super.key,
    required this.projectId,
    required this.gewerkId,
    required this.module,
    required this.person,
    required this.actor,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  State<_ContactPersonTile> createState() => _ContactPersonTileState();
}

class _ContactPersonTileState extends State<_ContactPersonTile> {
  late final _phoneController =
      TextEditingController(text: widget.person.phone);

  @override
  void didUpdateWidget(covariant _ContactPersonTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mit einem stabilen Key (siehe Aufrufstelle) bleibt dieses State-Objekt
    // über Rebuilds hinweg derselben Person zugeordnet - ändert sich ihre
    // Telefonnummer extern (z.B. Sync-Merge von einem anderen Gerät), muss
    // das Feld trotzdem nachgezogen werden, sonst zeigt es die veraltete
    // Nummer, obwohl der Nutzer gerade nichts eingibt.
    if (oldWidget.person.phone != widget.person.phone &&
        _phoneController.text != widget.person.phone) {
      _phoneController.text = widget.person.phone;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<ProjectStore>();
    final projectId = widget.projectId;
    final gewerkId = widget.gewerkId;
    final module = widget.module;
    final person = widget.person;
    final actor = widget.actor;
    final onCall = widget.onCall;
    final onWhatsApp = widget.onWhatsApp;
    final phoneController = _phoneController;
    final hasPhone = person.phone.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  person.name.isEmpty ? "(ohne Name)" : person.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: "Person entfernen",
                onPressed: () => store.removeContactPerson(
                  projectId,
                  gewerkId,
                  module.id,
                  person.id,
                  actor: actor,
                ),
              ),
            ],
          ),
          TextFormField(
            controller: phoneController,
            decoration: const InputDecoration(labelText: "Telefonnummer"),
            keyboardType: TextInputType.phone,
            onFieldSubmitted: (value) => store.updateContactPerson(
              projectId,
              gewerkId,
              module.id,
              person.id,
              name: person.name,
              phone: value,
              actor: actor,
            ),
          ),
          if (hasPhone)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => onCall(person.phone),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text("Anrufen"),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => onWhatsApp(person.phone),
                    icon:
                        const Icon(Icons.chat, size: 18, color: Colors.green),
                    label: const Text("WhatsApp"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
