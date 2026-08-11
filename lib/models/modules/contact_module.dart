import '../audit_entry.dart';
import 'gewerk_module.dart';

// Eine einzelne Person innerhalb eines Kontakt-Moduls (z.B. ein Maurer
// unter mehreren im Modul "Maurer"). Ein Modul kann beliebig viele
// Personen enthalten.
class ContactPerson {
  String id;
  String name;
  String phone;

  ContactPerson({
    required this.id,
    this.name = '',
    this.phone = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
      };

  factory ContactPerson.fromMap(Map<String, dynamic> map) => ContactPerson(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
      );
}

class ContactModule extends GewerkModule {
  static const moduleType = 'contact';

  // Mehrere Personen pro Modul möglich, z.B. mehrere Maurer im selben
  // "Maurer"-Modul.
  List<ContactPerson> contacts;

  // Verlauf: wer hat Kontakte zuletzt hinzugefügt/bearbeitet/entfernt.
  List<AuditEntry> history;

  ContactModule(
    super.id, {
    super.label,
    List<ContactPerson>? contacts,
    List<AuditEntry>? history,
  })  : contacts = contacts ?? [],
        history = history ?? [];

  @override
  String get type => moduleType;

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'id': id,
        'label': label,
        'contacts': contacts.map((c) => c.toMap()).toList(),
        'history': history.map((h) => h.toMap()).toList(),
      };

  factory ContactModule.fromMap(Map<String, dynamic> map) {
    final rawContacts = map['contacts'] as List<dynamic>?;
    final List<ContactPerson> contacts;
    if (rawContacts != null) {
      contacts = rawContacts
          .map((e) => ContactPerson.fromMap(e as Map<String, dynamic>))
          .toList();
    } else {
      // Altformat (vor Mehrfach-Kontakten): ein einzelner Kontakt lag
      // direkt als name/phone am Modul.
      final legacyName = map['name'] as String? ?? '';
      final legacyPhone = map['phone'] as String? ?? '';
      contacts = (legacyName.isEmpty && legacyPhone.isEmpty)
          ? []
          : [
              ContactPerson(
                id: map['id'] as String,
                name: legacyName,
                phone: legacyPhone,
              ),
            ];
    }
    return ContactModule(
      map['id'] as String,
      label: map['label'] as String? ?? '',
      contacts: contacts,
      history: (map['history'] as List<dynamic>? ?? [])
          .map((e) => AuditEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
