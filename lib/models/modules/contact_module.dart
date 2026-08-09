import '../audit_entry.dart';
import 'gewerk_module.dart';

class ContactModule extends GewerkModule {
  static const moduleType = 'contact';

  String name;
  String phone;

  // Verlauf: wer hat den Kontakt zuletzt bearbeitet.
  List<AuditEntry> history;

  ContactModule(
    super.id, {
    super.label,
    this.name = '',
    this.phone = '',
    List<AuditEntry>? history,
  }) : history = history ?? [];

  @override
  String get type => moduleType;

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'id': id,
        'label': label,
        'name': name,
        'phone': phone,
        'history': history.map((h) => h.toMap()).toList(),
      };

  factory ContactModule.fromMap(Map<String, dynamic> map) => ContactModule(
        map['id'] as String,
        label: map['label'] as String? ?? '',
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        history: (map['history'] as List<dynamic>? ?? [])
            .map((e) => AuditEntry.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}
