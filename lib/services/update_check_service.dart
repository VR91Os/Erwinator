import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'error_log_service.dart';

const _releasesUrl =
    'https://api.github.com/repos/VR91Os/Erwinator/releases/latest';
const _lastCheckKey = 'update_check_last_checked';
const _checkInterval = Duration(hours: 24);

class UpdateInfo {
  final String version;
  final String downloadUrl;
  UpdateInfo({required this.version, required this.downloadUrl});
}

// Vergleicht zwei "x.y.z"-Versionsstrings (führendes "v" und ein "+build"-
// Suffix werden ignoriert). Gibt true zurück, wenn [remote] echt neuer als
// [local] ist. Bewusst ohne neue Abhängigkeit (kein pub_semver) - die
// Versionsschemata hier sind einfache Zahlentripel.
bool _isNewer(String remote, String local) {
  List<int> parse(String v) {
    final cleaned = v.trim().replaceFirst(RegExp(r'^v'), '').split('+').first;
    return cleaned
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList(growable: false);
  }

  final r = parse(remote);
  final l = parse(local);
  for (var i = 0; i < r.length || i < l.length; i++) {
    final rv = i < r.length ? r[i] : 0;
    final lv = i < l.length ? l[i] : 0;
    if (rv != lv) return rv > lv;
  }
  return false;
}

// Prüft gegen die GitHub-Releases-API, ob eine neuere App-Version verfügbar
// ist - kein eigenes Backend nötig, das Repo ist öffentlich. Scheitert der
// Check (kein Internet, GitHub nicht erreichbar, Rate-Limit), wird das als
// "kein Update gefunden" behandelt statt als Fehler hochgereicht, damit ein
// App-Start nie an einem Update-Check hängen bleibt.
class UpdateCheckService {
  UpdateCheckService._() : _client = http.Client();
  // Für Tests: eigener Client statt des echten Netzwerk-Requests.
  UpdateCheckService.withClient(this._client);
  static final instance = UpdateCheckService._();

  final http.Client _client;

  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!force) {
        final lastChecked = prefs.getString(_lastCheckKey);
        if (lastChecked != null) {
          final last = DateTime.tryParse(lastChecked);
          if (last != null &&
              DateTime.now().difference(last) < _checkInterval) {
            return null;
          }
        }
      }

      final response = await _client
          .get(Uri.parse(_releasesUrl))
          .timeout(const Duration(seconds: 10));
      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = body['tag_name'] as String?;
      if (tagName == null) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      if (!_isNewer(tagName, packageInfo.version)) return null;

      final assets = body['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final map = asset as Map<String, dynamic>;
        final name = map['name'] as String? ?? '';
        if (name.contains('arm64-v8a')) {
          final url = map['browser_download_url'] as String?;
          if (url == null) return null;
          return UpdateInfo(
            version: tagName.replaceFirst(RegExp(r'^v'), ''),
            downloadUrl: url,
          );
        }
      }
      return null;
    } catch (e, stack) {
      ErrorLogService.instance.record('Update-Check fehlgeschlagen', '$e\n$stack');
      return null;
    }
  }
}
