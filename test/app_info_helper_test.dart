import 'package:app_info_helper/app_info_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app_info_helper');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('refresh loads native values into synchronous getters', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getAll');
      return <String, Object>{
        'appName': 'Example',
        'packageName': 'com.example.app',
        'version': '1.2.3',
        'deviceModel': 'Pixel',
        'languageCode': 'zh',
        'languageCode3': 'zho',
        'countryCode': 'CN',
        'countryCode3': 'CHN',
      };
    });

    await AppInfoHelper().refresh();

    expect(AppInfoHelper().appName, 'Example');
    expect(AppInfoHelper().packageName, 'com.example.app');
    expect(AppInfoHelper().version, '1.2.3');
    expect(AppInfoHelper().deviceModel, 'Pixel');
    expect(AppInfoHelper().languageCode, 'zh');
    expect(AppInfoHelper().languageCode3, 'zho');
    expect(AppInfoHelper().countryCode, 'CN');
    expect(AppInfoHelper().countryCode3, 'CHN');
  });

  test('locale getters use documented fallbacks', () {
    expect(AppInfoHelper().languageCode, isNotEmpty);
    expect(AppInfoHelper().languageCode3, isNotEmpty);
    expect(AppInfoHelper().countryCode, isNotEmpty);
    expect(AppInfoHelper().countryCode3, isNotEmpty);
  });
}
