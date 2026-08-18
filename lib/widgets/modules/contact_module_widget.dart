import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/modules/contact_module.dart';
import '../../models/project.dart';
import '../../state/project_store.dart';
import '../../state/settings_store.dart';
import '../../utils/name_capitalization.dart';
import '../audit_info_icon.dart';
import 'module_card.dart';

// Entfernt versehentlich mitgetippte/eingefügte Leerzeichen aus einer
// Email-Adresse (z.B. beim Copy-Paste aus einer PDF).
String _stripEmailSpaces(String value) => value.replaceAll(RegExp(r'\s+'), '');

// Einfache Plausibilitätsprüfung (nicht RFC-vollständig, reicht aber für
// Tippfehler wie fehlendes "@" oder fehlende Domain) - leer gilt als
// gültig, da das Feld optional ist.
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
bool _isValidEmail(String value) => value.isEmpty || _emailPattern.hasMatch(value);

// Die Prüfung ist nur eine Plausibilitätshilfe, keine echte RFC-Validierung
// - manche seltenen, aber gültigen Adressen fallen durch. Statt hart zu
// blockieren, kann der Nutzer die Warnung bewusst ignorieren und trotzdem
// speichern.
// Bei mehreren kommagetrennten Namen gäbe es keine eindeutige Zuordnung,
// wem eine gleichzeitig eingetragene Email gehört - statt sie dann
// stillschweigend zu verwerfen (der Nutzer könnte annehmen, sie wäre allen
// zugewiesen worden), muss das hier bewusst bestätigt werden.
Future<bool> _confirmDropEmailForMultipleNames(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Email wird nicht übernommen"),
      content: const Text(
        "Bei mehreren, kommagetrennten Namen kann die eingetragene "
        "Email-Adresse nicht eindeutig zugeordnet werden und bleibt "
        "leer. Um sie zu übernehmen, füge die Person einzeln hinzu.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Bearbeiten"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text("Ohne Email fortfahren"),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> _confirmSaveInvalidEmail(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Email-Adresse prüfen"),
      content: const Text(
        "Die Email-Adresse sieht ungültig aus (kein \"@\" oder keine Domain "
        "erkannt). Falls es sich um eine unübliche, aber tatsächlich "
        "gültige Adresse handelt, kannst du die Prüfung ignorieren.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Bearbeiten"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text("Ignorieren, trotzdem speichern"),
        ),
      ],
    ),
  );
  return result ?? false;
}

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
  void _addManually(BuildContext context, {required bool showContactEmail}) {
    final store = context.read<ProjectStore>();
    final actor = context.read<SettingsStore>().currentUserKurzzeichen;
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Person manuell hinzufügen"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                inputFormatters: const [NameCapitalizationFormatter()],
                decoration: const InputDecoration(
                  labelText: "Name *",
                  helperText: "Mehrere Personen mit Komma trennen",
                ),
                autofocus: true,
              ),
              if (showContactEmail) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () async {
                final names = splitNames(nameController.text);
                if (names.isEmpty) return;
                // Die eingetragene Email gehört zu EINER Person - bei
                // mehreren kommagetrennten Namen gäbe es sonst keine
                // eindeutige Zuordnung, wem sie gehört, deshalb dann leer
                // lassen statt sie allen gleichermaßen zuzuweisen. Das muss
                // der Nutzer bestätigen, statt die Email stillschweigend zu
                // verlieren.
                if (names.length > 1 &&
                    emailController.text.trim().isNotEmpty) {
                  final proceed =
                      await _confirmDropEmailForMultipleNames(dialogContext);
                  if (!dialogContext.mounted) return;
                  if (!proceed) return;
                }
                final email = names.length == 1
                    ? _stripEmailSpaces(emailController.text.trim())
                    : '';
                if (!_isValidEmail(email)) {
                  final proceed = await _confirmSaveInvalidEmail(dialogContext);
                  if (!proceed) return;
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                // Erst nach dem aktuellen Frame speichern (siehe
                // time_tracking_section.dart _showManualTimeDialog): die
                // store.addContactPerson-Aufrufe lösen über notifyListeners()
                // einen Provider-weiten Rebuild aus - passiert das noch
                // synchron, während Navigator.pop den Dialog gerade abbaut,
                // kollidiert das mit dessen Element-Abbau
                // ("_dependents.isEmpty"-Assertion).
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  for (final name in names) {
                    store.addContactPerson(
                      projectId,
                      gewerkId,
                      module.id,
                      name: name,
                      email: email,
                      actor: actor,
                    );
                  }
                });
              },
              child: const Text("Hinzufügen"),
            ),
          ],
        );
      },
    ).then((_) {
      nameController.dispose();
      emailController.dispose();
    });
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

  // Nur am Smartphone sinnvoll (Gmail-App bzw. E-Mail-App gibt es auf
  // Desktop/Web nicht in gleicher Form).
  bool get _isSmartphone =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // Öffnet direkt die Gmail-App. Android: über ein natives Intent-Objekt
  // (android_intent_plus) mit explizitem Package - url_launcher kann das
  // NICHT: sein Android-Code baut aus jeder übergebenen URL immer nur ein
  // simples ACTION_VIEW-Intent per setData(Uri.parse(url)) (siehe
  // UrlLauncher.java im Plugin), ohne je Intent.parseUri() aufzurufen. Ein
  // "intent://...#Intent;...;end"-String (das "Chrome Intents"-Format, wie
  // hier vorher versucht) wird von Android darüber NIE als Intent
  // interpretiert - das Zielpaket öffnet sich nie, unabhängig von der
  // genauen URI-Syntax. android_intent_plus baut dagegen ein echtes
  // Intent-Objekt (Action + Category + Package), genau wie ein Tap auf das
  // App-Icon. Ist Gmail nicht installiert, fällt es auf die Standard-Mail-
  // App des Geräts zurück. iOS: googlegmail:// wird dort tatsächlich als
  // Custom-URL-Scheme von der Gmail-App registriert, das funktioniert über
  // den normalen URL-Launcher.
  //
  // FLAG_ACTIVITY_NEW_TASK ist hier Pflicht, kein optionales Detail: ohne
  // das Flag hängt sich Gmails Activity, wenn sie ohne eigenen neuen Task
  // gestartet wird, an den BESTEHENDEN Task von Erwinator (unserer eigenen
  // Activity) an, statt einen eigenen zu bekommen - für den Nutzer sah das
  // dann so aus, als würde "Gmail in Erwinator laufen", und Zurück brachte
  // ihn nicht mehr in die App zurück (musste sie neu starten). Mit dem
  // Flag bekommt Gmail garantiert einen eigenen, unabhängigen Task -
  // Erwinators eigener Task/Activity bleibt davon unberührt im
  // Hintergrund, Zurückkehren läuft über den App-Wechsler.
  Future<void> _openGmail(BuildContext context) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      const gmailIntent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.LAUNCHER',
        package: 'com.google.android.gm',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      final resolvable = await gmailIntent.canResolveActivity() ?? false;
      if (resolvable) {
        await gmailIntent.launch();
        return;
      }
    } else {
      final launched = await launchUrl(Uri.parse('googlegmail://'));
      if (launched) return;
    }
    final fallback = await launchUrl(Uri.parse('mailto:'));
    if (!fallback && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gmail konnte nicht geöffnet werden.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = context.watch<SettingsStore>().currentUserKurzzeichen;
    final store = context.watch<ProjectStore>();
    Project? project;
    for (final p in store.projects) {
      if (p.id == projectId) project = p;
    }
    final showContactEmail = project?.showContactEmail ?? false;

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
          if (_isSmartphone)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: () => _openGmail(context),
                  icon: const Icon(Icons.email_outlined, size: 18),
                  label: const Text("Gmail öffnen"),
                ),
              ),
            ),
          Row(
            children: [
              // Kontaktauswahl gibt es auf Web ohnehin nicht (flutter_contacts
              // ist Android/iOS-only) - Button gar nicht erst anzeigen statt
              // erst nach Antippen mit einer Fehlermeldung zu reagieren.
              if (!kIsWeb)
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
                showContactEmail: showContactEmail,
                onCall: (phone) => _call(context, phone),
                onWhatsApp: (phone) => _openWhatsApp(context, phone),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addManually(context,
                  showContactEmail: showContactEmail),
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
  final bool showContactEmail;
  final void Function(String phone) onCall;
  final void Function(String phone) onWhatsApp;

  const _ContactPersonTile({
    super.key,
    required this.projectId,
    required this.gewerkId,
    required this.module,
    required this.person,
    required this.actor,
    required this.showContactEmail,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  State<_ContactPersonTile> createState() => _ContactPersonTileState();
}

class _ContactPersonTileState extends State<_ContactPersonTile> {
  late final _emailController =
      TextEditingController(text: widget.person.email);

  @override
  void didUpdateWidget(covariant _ContactPersonTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mit einem stabilen Key (siehe Aufrufstelle) bleibt dieses State-Objekt
    // über Rebuilds hinweg derselben Person zugeordnet - ändert sich ihre
    // Email extern (z.B. Sync-Merge von einem anderen Gerät), muss das Feld
    // trotzdem nachgezogen werden, sonst zeigt es den veralteten Wert,
    // obwohl der Nutzer gerade nichts eingibt.
    if (oldWidget.person.email != widget.person.email &&
        _emailController.text != widget.person.email) {
      _emailController.text = widget.person.email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
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
                  // Die Karte bleibt bewusst immer hellgrau (auch im
                  // Dunkelmodus) - ohne feste Textfarbe würde der Name im
                  // Dunkelmodus die helle Standard-Textfarbe erben und
                  // kaum lesbar sein.
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.black54),
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
          if (widget.showContactEmail)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: "Email kopieren",
                    onPressed: person.email.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                                ClipboardData(text: person.email));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Email kopiert")),
                            );
                          },
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                onFieldSubmitted: (value) async {
                  final cleaned = _stripEmailSpaces(value);
                  if (cleaned != value) _emailController.text = cleaned;
                  if (!_isValidEmail(cleaned)) {
                    final proceed = await _confirmSaveInvalidEmail(context);
                    if (!proceed) return;
                  }
                  store.updateContactPerson(
                    projectId,
                    gewerkId,
                    module.id,
                    person.id,
                    name: person.name,
                    phone: person.phone,
                    email: cleaned,
                    actor: actor,
                  );
                },
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
