import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/modules/contact_module.dart';
import '../../state/project_store.dart';
import '../../state/settings_store.dart';
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

  Future<void> _pickFromContacts(BuildContext context) async {
    final store = context.read<ProjectStore>();
    final actor = context.read<SettingsStore>().currentUserKurzzeichen;
    try {
      final contact = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.phone},
      );
      if (contact == null || !context.mounted) return;
      final phone = contact.phones.isEmpty ? '' : contact.phones.first.number;
      store.updateContactModule(
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
    final launched =
        await launchUrl(Uri.parse('https://wa.me/$digits'));
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
    final hasPhone = module.phone.trim().isNotEmpty;

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
          TextFormField(
            initialValue: module.name,
            decoration: const InputDecoration(labelText: "Name"),
            onFieldSubmitted: (value) {
              context.read<ProjectStore>().updateContactModule(
                    projectId,
                    gewerkId,
                    module.id,
                    name: value,
                    phone: module.phone,
                    actor: actor,
                  );
            },
          ),
          TextFormField(
            initialValue: module.phone,
            decoration: const InputDecoration(labelText: "Telefonnummer"),
            keyboardType: TextInputType.phone,
            onFieldSubmitted: (value) {
              context.read<ProjectStore>().updateContactModule(
                    projectId,
                    gewerkId,
                    module.id,
                    name: module.name,
                    phone: value,
                    actor: actor,
                  );
            },
          ),
          if (hasPhone)
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _call(context, module.phone),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text("Anrufen"),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openWhatsApp(context, module.phone),
                  icon: const Icon(Icons.chat, size: 18, color: Colors.green),
                  label: const Text("WhatsApp"),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
