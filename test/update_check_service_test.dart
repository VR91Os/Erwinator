import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baustelli/services/update_check_service.dart';

http.Client _mockClient(String body, {int statusCode = 200}) =>
    MockClient((request) async => http.Response(body, statusCode));

const _releaseJson = '''
{
  "tag_name": "v9.9.9",
  "assets": [
    {"name": "app-arm64-v8a-release.apk", "browser_download_url": "https://example.com/app-arm64-v8a-release.apk"}
  ]
}
''';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Baustelli',
      packageName: 'at.erwinator.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  test('erkennt eine neuere Version und liefert die arm64-v8a-Download-URL',
      () async {
    final service = UpdateCheckService.withClient(_mockClient(_releaseJson));
    final update = await service.checkForUpdate(force: true);

    expect(update, isNotNull);
    expect(update!.version, '9.9.9');
    expect(update.downloadUrl,
        'https://example.com/app-arm64-v8a-release.apk');
  });

  test('liefert null, wenn die installierte Version bereits aktuell ist',
      () async {
    PackageInfo.setMockInitialValues(
      appName: 'Baustelli',
      packageName: 'at.erwinator.app',
      version: '9.9.9',
      buildNumber: '1',
      buildSignature: '',
    );
    final service = UpdateCheckService.withClient(_mockClient(_releaseJson));
    final update = await service.checkForUpdate(force: true);

    expect(update, isNull);
  });

  test('liefert null statt zu werfen, wenn die Anfrage fehlschlägt',
      () async {
    final service =
        UpdateCheckService.withClient(_mockClient('nicht gefunden', statusCode: 404));
    final update = await service.checkForUpdate(force: true);

    expect(update, isNull);
  });

  test('ohne force wird innerhalb von 24h nach dem letzten Check kein '
      'erneuter Request gemacht', () async {
    SharedPreferences.setMockInitialValues({
      'update_check_last_checked': DateTime.now().toIso8601String(),
    });
    var requested = false;
    final client = MockClient((request) async {
      requested = true;
      return http.Response(_releaseJson, 200);
    });
    final service = UpdateCheckService.withClient(client);
    final update = await service.checkForUpdate();

    expect(update, isNull);
    expect(requested, isFalse);
  });
}
