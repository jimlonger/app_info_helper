library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Cached native app, device, locale and identifier information.
///
/// Call [init] once during application startup. If initialization fails,
/// later getters/functions will retry initialization automatically.
/// All string getters are never null: unavailable values are returned as an
/// empty string or their documented fallback.
class AppInfoHelper with WidgetsBindingObserver {
  factory AppInfoHelper() => _instance;
  AppInfoHelper._();
  static final AppInfoHelper _instance = AppInfoHelper._();
  static const MethodChannel _channel = MethodChannel('app_info_helper');

  /// Shared singleton instance.
  ///
  /// Synchronous getters automatically start initialization when needed. The
  /// first read may still return the documented fallback value while native
  /// values are loading; await [init] or [ready] when the actual value is
  /// required immediately.
  static AppInfoHelper get instance => _instance;

  Map<String, dynamic> _data = <String, dynamic>{};
  Future<bool>? _initializing;
  LocalIdStorageOptions _localIdStorageOptions = const LocalIdStorageOptions();
  bool _loadedNativeValues = false;
  bool _observing = false;

  bool get isInitialized => _initializing == null && _loadedNativeValues;

  /// Ensures native values have been loaded, then returns [instance].
  Future<AppInfoHelper> get ready async {
    await init();
    return this;
  }

  /// Fetches all values once. Concurrent calls share the same native request.
  ///
  /// Returns `true` when native data was loaded successfully, and `false` when
  /// initialization failed or returned no values. Failures are kept internal so
  /// app startup does not crash.
  Future<bool> init({
    LocalIdStorageOptions localIdStorageOptions = const LocalIdStorageOptions(),
  }) {
    _validateLocalIdStorageOptions(localIdStorageOptions);
    _localIdStorageOptions = localIdStorageOptions;
    return _initializing ??= _loadSafely().whenComplete(() {
      _initializing = null;
    });
  }

  Future<bool> refresh() => _loadSafely();

  Future<void> configureLocalIds(LocalIdStorageOptions options) async {
    _validateLocalIdStorageOptions(options);
    _localIdStorageOptions = options;
    _data = <String, dynamic>{..._data}
      ..remove('primaryLocalId')
      ..remove('secondaryLocalId')
      ..remove('localIdsPersisted');
    _merge(await _call('readAllLocalIds'));
    _ensureLocalIdsInMemory();
  }

  Future<void> refreshAdvertisingId() async {
    await _ensureInitialized();
    _merge(await _call('refreshAdvertisingId'));
  }

  Future<void> refreshDeviceId() async {
    await _ensureInitialized();
    _merge(await _call('refreshDeviceId'));
  }

  Future<String> readLocalId({
    LocalIdSlot slot = LocalIdSlot.primary,
  }) async {
    await _ensureInitialized();
    _merge(
        await _call('readLocalId', <String, dynamic>{'slot': slot.wireName}));
    _ensureLocalIdsInMemory();
    return _s(_localIdDataKey(slot));
  }

  Future<void> writeLocalId(
    String value, {
    LocalIdSlot slot = LocalIdSlot.primary,
  }) async {
    if (value.isEmpty) {
      throw ArgumentError.value(value, 'value', 'Local ID cannot be empty.');
    }
    await _ensureInitialized();
    _merge(await _call('writeLocalId', <String, dynamic>{
      'slot': slot.wireName,
      'value': value,
    }));
    _data = <String, dynamic>{..._data, _localIdDataKey(slot): value};
  }

  Future<void> deleteLocalId({
    LocalIdSlot slot = LocalIdSlot.primary,
  }) async {
    await _ensureInitialized();
    await _call('deleteLocalId', <String, dynamic>{'slot': slot.wireName});
    _data = <String, dynamic>{..._data}..remove(_localIdDataKey(slot));
  }

  Future<bool> containsLocalId({
    LocalIdSlot slot = LocalIdSlot.primary,
  }) async {
    await _ensureInitialized();
    final values = await _call(
        'containsLocalId', <String, dynamic>{'slot': slot.wireName});
    return values['containsKey'] == true;
  }

  Future<String> resetLocalId({
    LocalIdSlot slot = LocalIdSlot.primary,
  }) async {
    await _ensureInitialized();
    _merge(
        await _call('resetLocalId', <String, dynamic>{'slot': slot.wireName}));
    _ensureLocalIdsInMemory();
    return _s(_localIdDataKey(slot));
  }

  Future<Map<LocalIdSlot, String>> readAllLocalIds() async {
    await _ensureInitialized();
    _merge(await _call('readAllLocalIds'));
    _ensureLocalIdsInMemory();
    return <LocalIdSlot, String>{
      LocalIdSlot.primary: primaryLocalId,
      LocalIdSlot.secondary: secondaryLocalId,
    };
  }

  Future<void> deleteAllLocalIds() async {
    await _ensureInitialized();
    await _call('deleteAllLocalIds');
    _data = <String, dynamic>{..._data}
      ..remove('primaryLocalId')
      ..remove('secondaryLocalId');
  }

  Future<Map<LocalIdSlot, String>> resetAllLocalIds() async {
    await _ensureInitialized();
    _merge(await _call('resetAllLocalIds'));
    _ensureLocalIdsInMemory();
    return <LocalIdSlot, String>{
      LocalIdSlot.primary: primaryLocalId,
      LocalIdSlot.secondary: secondaryLocalId,
    };
  }

  /// Requests iOS ATT. Android returns an `unavailable` failure result.
  Future<IdfaAuthorizationResult> requestIdfaAuthorization({
    void Function(String idfa)? onSuccess,
    void Function(IdfaAuthorizationFailure failure)? onFailure,
  }) async {
    await _ensureInitialized();
    final result = IdfaAuthorizationResult._(
      await _call('requestIdfaAuthorization'),
    );
    _merge(result._data);
    if (result.isSuccess) {
      onSuccess?.call(result.idfa);
    } else {
      onFailure?.call(result.failure);
    }
    return result;
  }

  Future<bool> _load() async {
    final values = await _call('getAll');
    if (values.isEmpty) {
      _ensureLocalIdsInMemory();
      return false;
    }
    _merge(values);
    _ensureLocalIdsInMemory();
    _loadedNativeValues = true;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    return _data['localIdsPersisted'] != false;
  }

  Future<bool> _loadSafely() async {
    try {
      return _load();
    } catch (_) {
      // Keep initialization failures internal so callers never need startup
      // crash handling for this helper.
      _ensureLocalIdsInMemory();
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadSafely());
    }
  }

  Future<void> _ensureInitialized() async {
    if (!isInitialized) {
      await init();
    }
  }

  void _ensureInitializedSoon() {
    if (!isInitialized) {
      unawaited(init());
    }
  }

  Future<Map<String, dynamic>> _call(
    String method, [
    Map<String, dynamic> arguments = const <String, dynamic>{},
  ]) async {
    try {
      return (await _channel.invokeMapMethod<String, dynamic>(
            method,
            <String, dynamic>{
              ...arguments,
              'localIdStorageOptions': _localIdStorageOptions.toMap(),
            },
          )) ??
          <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  void _merge(Map<String, dynamic> value) =>
      _data = <String, dynamic>{..._data, ...value};

  void _ensureLocalIdsInMemory() {
    final data = <String, dynamic>{..._data};
    if ((data['primaryLocalId']?.toString() ?? '').isEmpty) {
      data['primaryLocalId'] = _uuidV4();
      data['localIdsPersisted'] = false;
    }
    if ((data['secondaryLocalId']?.toString() ?? '').isEmpty) {
      data['secondaryLocalId'] = _uuidV4();
      data['localIdsPersisted'] = false;
    }
    _data = data;
  }

  String _localIdDataKey(LocalIdSlot slot) => switch (slot) {
        LocalIdSlot.primary => 'primaryLocalId',
        LocalIdSlot.secondary => 'secondaryLocalId',
      };

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    final value = bytes.map(hex).join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  void _validateLocalIdStorageOptions(LocalIdStorageOptions options) {
    if (options.fallbackNamespace != null &&
        options.fallbackNamespace!.isEmpty) {
      throw ArgumentError.value(
        options.fallbackNamespace,
        'fallbackNamespace',
        'Fallback namespace cannot be empty.',
      );
    }
    if (options.primaryKey != null && options.primaryKey!.isEmpty) {
      throw ArgumentError.value(
        options.primaryKey,
        'primaryKey',
        'Primary local ID key cannot be empty.',
      );
    }
    if (options.secondaryKey != null && options.secondaryKey!.isEmpty) {
      throw ArgumentError.value(
        options.secondaryKey,
        'secondaryKey',
        'Secondary local ID key cannot be empty.',
      );
    }
    if (options.primaryKey != null &&
        options.secondaryKey != null &&
        options.primaryKey == options.secondaryKey) {
      throw ArgumentError.value(
        options.primaryKey,
        'primaryKey',
        'Primary and secondary local ID keys must be different.',
      );
    }
  }

  String _s(String key, [String fallback = '']) {
    _ensureInitializedSoon();
    return _data[key]?.toString() ?? fallback;
  }

  String _firstNonEmpty(List<String> values, String fallback) {
    for (final value in values) {
      if (value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  int _i(String key) {
    _ensureInitializedSoon();
    return (_data[key] as num?)?.toInt() ?? 0;
  }

  bool _b(String key) {
    _ensureInitializedSoon();
    return _data[key] == true;
  }

  List<String> _l(String key) {
    _ensureInitializedSoon();
    return ((_data[key] as List?) ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList(growable: false);
  }

  /// Full raw map, including all platform-only device_info_plus equivalents.
  Map<String, dynamic> get data {
    _ensureInitializedSoon();
    return Map<String, dynamic>.unmodifiable(_data);
  }

  // Unified device fields.
  String get deviceModel => _s('deviceModel');
  String get platform => _s('platform');
  String get osVersion => _s('osVersion');
  String get systemName => _s('systemName');
  String get deviceName => _s('deviceName');
  bool get isPhysicalDevice => _b('isPhysicalDevice');
  int get freeDiskSize => _i('freeDiskSize');
  int get totalDiskSize => _i('totalDiskSize');
  int get physicalRamSize => _i('physicalRamSize');
  int get availableRamSize => _i('availableRamSize');

  // package_info_plus fields.
  String get appName => _s('appName');
  String get packageName => _s('packageName');
  String get version => _s('version');
  String get buildNumber => _s('buildNumber');
  String get buildSignature => _s('buildSignature');
  String get installerStore => _s('installerStore');
  int get installTime => _i('installTime');
  int get updateTime => _i('updateTime');

  // Locale fields. These have the specified US/English fallbacks.
  String get languageCode =>
      _firstNonEmpty(<String>[_s('languageCode'), _s('languageCode3')], 'en');
  String get languageCode3 =>
      _firstNonEmpty(<String>[_s('languageCode3')], 'eng');
  String get countryCode =>
      _firstNonEmpty(<String>[_s('countryCode'), _s('countryCode3')], 'US');
  String get countryCode3 =>
      _firstNonEmpty(<String>[_s('countryCode3')], 'USA');
  String get locale => _s('locale', 'en_US');
  String get timeZone => _s('timeZone');
  int get utcOffsetSeconds => _i('utcOffsetSeconds');

  // Unified and individual identifiers.
  String get advertisingId => _s('advertisingId');
  String get deviceId => _s('deviceId');
  String get idfa => _s('idfa');
  String get andi => _s('andi');
  String get aifa => _s('aifa');
  String get gaid => _s('gaid');
  String get aaid => _s('aaid');
  String get oaid => _s('oaid');
  String get asid => _s('asid');
  String get idfv => _s('idfv');
  String get primaryLocalId => _s('primaryLocalId');
  String get secondaryLocalId => _s('secondaryLocalId');

  // AndroidDeviceInfo-only fields.
  String get androidBoard => _s('androidBoard');
  String get androidBootloader => _s('androidBootloader');
  String get androidBrand => _s('androidBrand');
  String get androidDevice => _s('androidDevice');
  String get androidDisplay => _s('androidDisplay');
  String get androidFingerprint => _s('androidFingerprint');
  String get androidHardware => _s('androidHardware');
  String get androidHost => _s('androidHost');
  String get androidId => _s('androidId');
  String get androidProduct => _s('androidProduct');
  List<String> get androidSupported32BitAbis => _l('androidSupported32BitAbis');
  List<String> get androidSupported64BitAbis => _l('androidSupported64BitAbis');
  List<String> get androidSupportedAbis => _l('androidSupportedAbis');
  String get androidTags => _s('androidTags');
  String get androidType => _s('androidType');
  List<String> get androidSystemFeatures => _l('androidSystemFeatures');
  bool get androidIsLowRamDevice => _b('androidIsLowRamDevice');
  String get androidBaseOs => _s('androidBaseOs');
  int get androidSdkInt => _i('androidSdkInt');
  String get androidRelease => _s('androidRelease');
  String get androidCodename => _s('androidCodename');
  String get androidIncremental => _s('androidIncremental');
  int get androidPreviewSdkInt => _i('androidPreviewSdkInt');
  String get androidSecurityPatch => _s('androidSecurityPatch');

  // IosDeviceInfo-only fields.
  String get iosModelName => _s('iosModelName');
  String get iosLocalizedModel => _s('iosLocalizedModel');
  bool get isiOSAppOnMac => _b('isiOSAppOnMac');
  bool get isiOSAppOnVision => _b('isiOSAppOnVision');
  String get iosUtsnameSysname => _s('iosUtsnameSysname');
  String get iosUtsnameNodename => _s('iosUtsnameNodename');
  String get iosUtsnameRelease => _s('iosUtsnameRelease');
  String get iosUtsnameVersion => _s('iosUtsnameVersion');
  String get iosUtsnameMachine => _s('iosUtsnameMachine');
}

enum LocalIdSlot {
  primary,
  secondary;

  String get wireName => switch (this) {
        primary => 'primary',
        secondary => 'secondary',
      };
}

class LocalIdStorageOptions {
  const LocalIdStorageOptions({
    this.fallbackNamespace,
    this.primaryKey,
    this.secondaryKey,
  });

  /// Used only when Android cannot read packageName or iOS cannot read
  /// bundleIdentifier. It is a storage namespace, not an encryption key.
  final String? fallbackNamespace;
  final String? primaryKey;
  final String? secondaryKey;

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (fallbackNamespace != null) 'fallbackNamespace': fallbackNamespace,
        if (primaryKey != null) 'primaryKey': primaryKey,
        if (secondaryKey != null) 'secondaryKey': secondaryKey,
      };
}

class IdfaAuthorizationResult {
  const IdfaAuthorizationResult._(this._data);
  final Map<String, dynamic> _data;
  bool get isSuccess => _data['isSuccess'] == true;
  String get idfa => _data['idfa']?.toString() ?? '';
  IdfaAuthorizationFailure get failure =>
      IdfaAuthorizationFailure.fromWire(_data['failure']?.toString());
}

enum IdfaAuthorizationFailure {
  none,
  denied,
  restricted,
  unavailable,
  invalidIdfa,
  systemError;

  static IdfaAuthorizationFailure fromWire(String? value) => switch (value) {
        'denied' => denied,
        'restricted' => restricted,
        'unavailable' => unavailable,
        'invalidIdfa' => invalidIdfa,
        'systemError' => systemError,
        _ => none,
      };
}
