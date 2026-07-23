import 'package:app_info_helper/app_info_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app_info_helper');

  test('instance is the shared singleton entry point', () {
    expect(identical(AppInfoHelper.instance, AppInfoHelper()), isTrue);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('init returns true and loads native values into synchronous getters',
      () async {
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

    final initialized = await AppInfoHelper.instance.init();

    expect(initialized, isTrue);
    expect(AppInfoHelper.instance.appName, 'Example');
    expect(AppInfoHelper.instance.packageName, 'com.example.app');
    expect(AppInfoHelper.instance.version, '1.2.3');
    expect(AppInfoHelper.instance.deviceModel, 'Pixel');
    expect(AppInfoHelper.instance.languageCode, 'zh');
    expect(AppInfoHelper.instance.languageCode3, 'zho');
    expect(AppInfoHelper.instance.countryCode, 'CN');
    expect(AppInfoHelper.instance.countryCode3, 'CHN');
  });

  test('init returns false when native values are unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => <String, Object>{});

    final initialized = await AppInfoHelper.instance.init();

    expect(initialized, isFalse);
  });

  test('locale getters use documented fallbacks', () {
    expect(AppInfoHelper.instance.languageCode, isNotEmpty);
    expect(AppInfoHelper.instance.languageCode3, isNotEmpty);
    expect(AppInfoHelper.instance.countryCode, isNotEmpty);
    expect(AppInfoHelper.instance.countryCode3, isNotEmpty);
  });
}
