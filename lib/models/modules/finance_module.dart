import 'gewerk_module.dart';
import '../../utils/id_merge.dart';

// Besitzt bewusst KEINE eigenen Daten: zeigt nur eine nach gewerkId
// gefilterte Sicht auf die projektweite Project.financeEntries-Liste - wie
// TimeTrackingSection direkt auf Project.workDayEntries zugreift, statt
// eigene Kopien pro Gewerk zu halten. So bleibt eine einzige Quelle für
// die projektweite Finanzen-Gesamtübersicht.
class FinanceModule extends GewerkModule {
  static const moduleType = 'finance';

  FinanceModule(super.id, {super.label, super.updatedAt});

  @override
  String get type => moduleType;

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'id': id,
        'label': label,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FinanceModule.fromMap(Map<String, dynamic> map) => FinanceModule(
        map['id'] as String,
        label: map['label'] as String? ?? '',
        updatedAt: map['updatedAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(map['updatedAt'] as String),
      );

  @override
  GewerkModule mergeFrom(GewerkModule remote, Map<String, DateTime> tombstones) {
    if (remote is! FinanceModule) return this;
    final winner = newerOf(this, remote, (m) => m.updatedAt);
    return FinanceModule(id, label: winner.label, updatedAt: winner.updatedAt);
  }
}
