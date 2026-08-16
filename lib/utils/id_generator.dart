import 'dart:math';

final Random _random = Random.secure();

// UUID v4 (RFC 4122): 122 Bit echte Zufallsentropie statt eines
// In-Process-Zählers, der bei jedem App-Start bei 0 beginnt. IDs sind der
// Merge-Schlüssel für den Multi-Device-Sync (siehe id_merge.dart) – eine
// Kollision zwischen zwei Geräten würde dort zwei unabhängige Elemente
// stillschweigend zusammenführen, daher braucht es kryptographisch
// belastbare Eindeutigkeit statt nur zeitlicher Streuung.
String newId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10

  String hex(int start, int end) => bytes
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
