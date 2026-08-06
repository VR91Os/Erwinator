import 'gewerk_module.dart';

class ContactModule extends GewerkModule {
  static const moduleType = 'contact';

  String name;
  String phone;

  ContactModule(super.id, {this.name = '', this.phone = ''});

  @override
  String get type => moduleType;

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'id': id,
        'name': name,
        'phone': phone,
      };

  factory ContactModule.fromMap(Map<String, dynamic> map) => ContactModule(
        map['id'] as String,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
      );
}
