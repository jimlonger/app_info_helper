import 'package:x_app_utils/x_app_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('x_app_utils');

  test('instance is the shared singleton entry point', () {
    expect(identical(XAppUtils.instance, XAppUtils()), isTrue);
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

    final initialized = await XAppUtils.instance.init();

    expect(initialized, isTrue);
    expect(XAppUtils.instance.appName, 'Example');
    expect(XAppUtils.instance.packageName, 'com.example.app');
    expect(XAppUtils.instance.version, '1.2.3');
    expect(XAppUtils.instance.deviceModel, 'Pixel');
    expect(XAppUtils.instance.languageCode, 'zh');
    expect(XAppUtils.instance.languageCode3, 'zho');
    expect(XAppUtils.instance.countryCode, 'CN');
    expect(XAppUtils.instance.countryCode3, 'CHN');
    expect(XAppUtils.instance.primaryLocalId, 'primary-id');
    expect(XAppUtils.instance.secondaryLocalId, 'secondary-id');
  });

  test('init returns false when native values are unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => <String, Object>{});

    final initialized = await XAppUtils.instance.init();

    expect(initialized, isFalse);
    expect(XAppUtils.instance.primaryLocalId, isNotEmpty);
    expect(XAppUtils.instance.secondaryLocalId, isNotEmpty);
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

    await XAppUtils.instance.init(
      localIdStorageOptions: const LocalIdStorageOptions(
        fallbackNamespace: 'fallback',
      ),
    );
    final value = await XAppUtils.instance.readLocalId(
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
    expect(XAppUtils.instance.languageCode, isNotEmpty);
    expect(XAppUtils.instance.languageCode3, isNotEmpty);
    expect(XAppUtils.instance.countryCode, isNotEmpty);
    expect(XAppUtils.instance.countryCode3, isNotEmpty);
  });

  test('identifier refreshes use separate native operations', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return switch (call.method) {
        'refreshAdvertisingId' => <String, Object>{
            'gaid': 'advertising-id',
            'advertisingId': 'advertising-id',
          },
        'refreshDeviceId' => <String, Object>{'asid': 'app-set-id'},
        _ => <String, Object>{},
      };
    });

    await XAppUtils.instance.refreshAdvertisingId();
    await XAppUtils.instance.refreshDeviceId();

    expect(methods, <String>['refreshAdvertisingId', 'refreshDeviceId']);
    expect(XAppUtils.instance.gaid, 'advertising-id');
    expect(XAppUtils.instance.asid, 'app-set-id');
  });

  test('failed local-ID writes do not overwrite cached values', () async {
    final original = XAppUtils.instance.primaryLocalId;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'writeLocalId') {
        return <String, Object>{'success': false};
      }
      return <String, Object>{};
    });

    await expectLater(
      XAppUtils.instance.writeLocalId('not-persisted'),
      throwsA(isA<StateError>()),
    );

    expect(XAppUtils.instance.primaryLocalId, original);
  });
}
