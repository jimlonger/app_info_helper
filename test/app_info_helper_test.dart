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
        'primaryLocalId': 'primary-id',
        'secondaryLocalId': 'secondary-id',
        'localIdsPersisted': true,
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
    expect(AppInfoHelper.instance.primaryLocalId, 'primary-id');
    expect(AppInfoHelper.instance.secondaryLocalId, 'secondary-id');
  });

  test('init returns false when native values are unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => <String, Object>{});

    final initialized = await AppInfoHelper.instance.init();

    expect(initialized, isFalse);
    expect(AppInfoHelper.instance.primaryLocalId, isNotEmpty);
    expect(AppInfoHelper.instance.secondaryLocalId, isNotEmpty);
  });

  test('local id methods pass slot and configured storage options', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getAll') {
        return <String, Object>{
          'primaryLocalId': 'primary-id',
          'secondaryLocalId': 'secondary-id',
          'localIdsPersisted': true,
        };
      }
      if (call.method == 'readLocalId') {
        return <String, Object>{
          'primaryLocalId': 'primary-id',
          'secondaryLocalId': 'secondary-read',
          'localIdsPersisted': true,
        };
      }
      return <String, Object>{};
    });

    await AppInfoHelper.instance.init(
      localIdStorageOptions: const LocalIdStorageOptions(
        fallbackNamespace: 'fallback',
      ),
    );
    final value = await AppInfoHelper.instance.readLocalId(
      slot: LocalIdSlot.secondary,
    );

    expect(value, 'secondary-read');
    expect(calls.last.method, 'readLocalId');
    expect(calls.last.arguments, containsPair('slot', 'secondary'));
    expect(
      calls.last.arguments['localIdStorageOptions'],
      containsPair('fallbackNamespace', 'fallback'),
    );
  });

  test('locale getters use documented fallbacks', () {
    expect(AppInfoHelper.instance.languageCode, isNotEmpty);
    expect(AppInfoHelper.instance.languageCode3, isNotEmpty);
    expect(AppInfoHelper.instance.countryCode, isNotEmpty);
    expect(AppInfoHelper.instance.countryCode3, isNotEmpty);
  });
}
