// Ein bekannter Teammitglied-Eintrag (z.B. eingeladener Nutzer). Das
// Kurzzeichen wird beim Anlegen automatisch erzeugt, siehe
// utils/kurzzeichen.dart.
class TeamMember {
  String id;
  String name;
  String email;
  String kurzzeichen;

  TeamMember({
    required this.id,
    required this.name,
    this.email = '',
    required this.kurzzeichen,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'kurzzeichen': kurzzeichen,
      };

  factory TeamMember.fromMap(Map<String, dynamic> map) => TeamMember(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        email: map['email'] as String? ?? '',
        kurzzeichen: map['kurzzeichen'] as String? ?? '',
      );
}
