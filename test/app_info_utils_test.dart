import 'package:app_info_utils/app_info_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app_info_utils');

  test('instance is the shared singleton entry point', () {
    expect(identical(AppInfoUtils.instance, AppInfoUtils()), isTrue);
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

    final initialized = await AppInfoUtils.instance.init();

    expect(initialized, isTrue);
    expect(AppInfoUtils.instance.appName, 'Example');
    expect(AppInfoUtils.instance.packageName, 'com.example.app');
    expect(AppInfoUtils.instance.version, '1.2.3');
    expect(AppInfoUtils.instance.deviceModel, 'Pixel');
    expect(AppInfoUtils.instance.languageCode, 'zh');
    expect(AppInfoUtils.instance.languageCode3, 'zho');
    expect(AppInfoUtils.instance.countryCode, 'CN');
    expect(AppInfoUtils.instance.countryCode3, 'CHN');
    expect(AppInfoUtils.instance.primaryLocalId, 'primary-id');
    expect(AppInfoUtils.instance.secondaryLocalId, 'secondary-id');
  });

  test('init returns false when native values are unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => <String, Object>{});

    final initialized = await AppInfoUtils.instance.init();

    expect(initialized, isFalse);
    expect(AppInfoUtils.instance.primaryLocalId, isNotEmpty);
    expect(AppInfoUtils.instance.secondaryLocalId, isNotEmpty);
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

    await AppInfoUtils.instance.init(
      localIdStorageOptions: const LocalIdStorageOptions(
        fallbackNamespace: 'fallback',
      ),
    );
    final value = await AppInfoUtils.instance.readLocalId(
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
    expect(AppInfoUtils.instance.languageCode, isNotEmpty);
    expect(AppInfoUtils.instance.languageCode3, isNotEmpty);
    expect(AppInfoUtils.instance.countryCode, isNotEmpty);
    expect(AppInfoUtils.instance.countryCode3, isNotEmpty);
  });
}
