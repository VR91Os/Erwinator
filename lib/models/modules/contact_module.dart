import '../../utils/id_merge.dart';
import '../audit_entry.dart';
import 'gewerk_module.dart';

// Eine einzelne Person innerhalb eines Kontakt-Moduls (z.B. ein Maurer
// unter mehreren im Modul "Maurer"). Ein Modul kann beliebig viele
// Personen enthalten.
class ContactPerson {
  String id;
  String name;
  String phone;
  DateTime updatedAt;

  ContactPerson({
    required this.id,
    this.name = '',
    this.phone = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ContactPerson.fromMap(Map<String, dynamic> map) => ContactPerson(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        updatedAt: map['updatedAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(map['updatedAt'] as String),
      );

  ContactPerson mergeFrom(ContactPerson remote) =>
      newerOf(this, remote, (c) => c.updatedAt);
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
    super.updatedAt,
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
        'updatedAt': updatedAt.toIso8601String(),
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
      updatedAt: map['updatedAt'] == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(map['updatedAt'] as String),
      contacts: contacts,
      history: (map['history'] as List<dynamic>? ?? [])
          .map((e) => AuditEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  GewerkModule mergeFrom(GewerkModule remote, Map<String, DateTime> tombstones) {
    if (remote is! ContactModule) return this;
    final winner = newerOf(this, remote, (m) => m.updatedAt);
    return ContactModule(
      id,
      label: winner.label,
      updatedAt: winner.updatedAt,
      contacts: mergeById<ContactPerson>(
        local: contacts,
        remote: remote.contacts,
        idOf: (c) => c.id,
        updatedAtOf: (c) => c.updatedAt,
        combine: (l, r) => l.mergeFrom(r),
        tombstones: tombstones,
      ),
      history: mergeHistory(history, remote.history),
    );
  }
}
