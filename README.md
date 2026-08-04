# x_app_utils

A Flutter plugin that exposes unified app, device, locale, timezone, and
identifier information on iOS and Android.

The package keeps native values cached in memory and initializes itself on
first use, so values can be read through synchronous getters in the rest of
your app.

## Features

- App metadata: app name, package name, version, build number, installer store,
  install time, update time, and Android build signature.
- Device and system metadata: model, manufacturer/platform, OS version, device
  name, physical device flag, disk size, and memory size.
- Locale and timezone metadata: language code, ISO-3 language code, country
  code, ISO-3 country code, locale, timezone, and UTC offset.
- Identifiers: IDFA, IDFV, Android ID, Google advertising ID, App Set ID,
  secure primary/secondary local IDs, and unified `advertisingId` / `deviceId`
  convenience getters.
- iOS ATT authorization helper for requesting IDFA access at the right moment in
  your app flow.
- Lifecycle-friendly EventBus helpers for plain Dart owners and Flutter
  `State` objects.

## Platform Field Guide

All fields are exposed from the same `XAppUtils.instance` API. Platform-specific
fields return documented fallbacks on unsupported platforms instead of `null`.

### App metadata

| Getter | Android | iOS |
| --- | --- | --- |
| `appName` | Application label | `CFBundleDisplayName` or `CFBundleName` |
| `packageName` | Android package name | Bundle identifier |
| `version` | `versionName` | `CFBundleShortVersionString` |
| `buildNumber` | `versionCode` / long version code | `CFBundleVersion` |
| `buildSignature` | SHA-256 signing certificate digest | `''` |
| `installerStore` | Installing package/store when available | `''` |
| `installTime` | First install time, milliseconds since epoch | `0` |
| `updateTime` | Last update time, milliseconds since epoch | `0` |

### Device, system, locale, and storage

| Getter | Android | iOS |
| --- | --- | --- |
| `deviceModel` | `Build.MODEL` | Hardware machine identifier, such as `iPhone16,1` |
| `platform` | `Build.MANUFACTURER` | `UIDevice.model` |
| `osVersion` | Android release | iOS system version |
| `systemName` | `Android` | `UIDevice.systemName` |
| `deviceName` | Device model/name fallback | `UIDevice.name` |
| `isPhysicalDevice` | Emulator heuristic | Simulator check |
| `freeDiskSize` / `totalDiskSize` | Data partition bytes | Home filesystem bytes |
| `physicalRamSize` | Total RAM in MiB | Physical memory in MiB |
| `availableRamSize` | Available RAM in MiB | `0` |
| `languageCode` / `languageCode3` | Locale language and ISO-3 code | Preferred language and ISO-3 code |
| `languageTag` | BCP-47 language tag without region | Preferred language tag without region |
| `languageScriptCode` | Script code when available | Script code when available |
| `countryCode` / `countryCode3` | Locale region and ISO-3 code | Preferred region and ISO-3 code |
| `locale` | Full locale tag | Full preferred language identifier |
| `timeZone` | Time zone ID | Time zone ID |
| `utcOffsetSeconds` | Current UTC offset | Current UTC offset |

### Identifiers

| Getter | Android | iOS |
| --- | --- | --- |
| `advertisingId` | Google Advertising ID after `refreshAdvertisingId()` | IDFA when authorized |
| `deviceId` | Android ID, App Set ID, then local ID fallback | IDFV, then local ID fallback |
| `idfa` / `idfv` | `''` | IDFA / IDFV |
| `gaid` / `aaid` / `aifa` | Google Advertising ID when available | `''` |
| `androidId` / `andi` | `Settings.Secure.ANDROID_ID` | `''` |
| `asid` | App Set ID after `refreshDeviceId()` or `getAll` | `''` |
| `primaryLocalId` / `secondaryLocalId` | Android KeyStore-backed encrypted values | Keychain-backed values |

### Android-only fields

`androidBoard`, `androidBootloader`, `androidBrand`, `androidDevice`,
`androidDisplay`, `androidFingerprint`, `androidHardware`, `androidHost`,
`androidProduct`, `androidSupported32BitAbis`, `androidSupported64BitAbis`,
`androidSupportedAbis`, `androidTags`, `androidType`,
`androidSystemFeatures`, `androidIsLowRamDevice`, `androidBaseOs`,
`androidSdkInt`, `androidRelease`, `androidCodename`,
`androidIncremental`, `androidPreviewSdkInt`, and
`androidSecurityPatch` are populated only on Android.

### iOS-only fields

`iosModelName`, `iosLocalizedModel`, `isiOSAppOnMac`, `isiOSAppOnVision`,
`iosUtsnameSysname`, `iosUtsnameNodename`, `iosUtsnameRelease`,
`iosUtsnameVersion`, and `iosUtsnameMachine` are populated only on iOS.

## Installation

```yaml
dependencies:
  x_app_utils: ^0.1.6
```

Then import the package:

```dart
import 'package:x_app_utils/x_app_utils.dart';
```

## Usage

For a complete Chinese integration guide, see
[doc/USAGE.md](doc/USAGE.md).

Read values from the shared instance:

```dart
final info = XAppUtils.instance;

final appName = info.appName;
final packageName = info.packageName;
final version = info.version;
final model = info.deviceModel;
final country = info.countryCode;
final timeZone = info.timeZone;
final deviceId = info.deviceId;
final primaryLocalId = info.primaryLocalId;
final secondaryLocalId = info.secondaryLocalId;
```

If native values have not been loaded yet, the first getter read starts loading
them automatically and returns the documented fallback value for that read.
Later reads return the cached native values.

`XAppUtils.instance` is the recommended entry point. `XAppUtils()` is
kept as a singleton factory for compatibility.

You may also initialize explicitly during app startup when you want to preload
native values:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialized = await XAppUtils.instance.init();
  if (!initialized) {
    // Some native values or secure local ID persistence are unavailable.
    // primaryLocalId and secondaryLocalId still have in-memory UUID fallbacks.
  }
  runApp(const MyApp());
}
```

`init()` returns `true` when native values were loaded and `false` when they
were unavailable. It does not throw for channel/native read failures.

If you must guarantee that native values are loaded before a local read, use:

```dart
final info = await XAppUtils.instance.ready;
final model = info.deviceModel;
```

## Refreshing Values

```dart
final refreshed = await XAppUtils.instance.refresh();
await XAppUtils.instance.refreshAdvertisingId();
await XAppUtils.instance.refreshDeviceId();
await XAppUtils.instance.resetLocalId();
```

The plugin also refreshes cached values when the app returns to the foreground.

## Advertising IDs and Android privacy

`init()` and foreground refreshes do not read advertising identifiers. Read the
Google advertising ID only when your app has obtained any required user consent:

```dart
await XAppUtils.instance.refreshAdvertisingId();
```

The package intentionally does not add Android's `AD_ID` permission to the host
app. If you use `refreshAdvertisingId()`, add it to the host application's
`android/app/src/main/AndroidManifest.xml` and complete the applicable Google
Play Data safety disclosure:

```xml
<uses-permission android:name="com.google.android.gms.permission.AD_ID" />
```

`refreshDeviceId()` reads Android's App Set ID on demand. Both calls return an
empty identifier when the relevant service, permission, or user setting makes
the value unavailable.

## Secure Local IDs

`primaryLocalId` and `secondaryLocalId` are UUID values generated independently
on each platform. Android stores them with Android KeyStore + RSA OAEP +
AES-GCM encrypted SharedPreferences. iOS stores them in Keychain with
`kSecAttrAccessibleWhenUnlocked`.

By default, storage keys use the Android package name or iOS bundle identifier.
If the platform namespace is temporarily unavailable, provide a fallback
namespace; when both namespaces are available on the same platform, values are
synchronized so future reads stay consistent.

```dart
await XAppUtils.instance.init(
  localIdStorageOptions: const LocalIdStorageOptions(
    fallbackNamespace: 'my_app',
  ),
);
```

Manage either local ID through a single slot-based API:

```dart
final primary = await XAppUtils.instance.readLocalId();
final secondary = await XAppUtils.instance.readLocalId(
  slot: LocalIdSlot.secondary,
);

await XAppUtils.instance.writeLocalId('custom-id');
final exists = await XAppUtils.instance.containsLocalId();
await XAppUtils.instance.deleteLocalId();
final newPrimary = await XAppUtils.instance.resetLocalId();
```

## iOS IDFA and ATT

`init()` never shows the ATT prompt. It only reads IDFA when tracking permission
has already been granted.

To request ATT authorization:

```dart
final result = await XAppUtils.instance.requestIdfaAuthorization();

if (result.isSuccess) {
  final idfa = result.idfa;
} else {
  final failure = result.failure;
}
```

Before calling `requestIdfaAuthorization()` in a real iOS app, add
`NSUserTrackingUsageDescription` to the host app's `ios/Runner/Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier is used to provide more relevant content and advertising.</string>
```

## Fallbacks

String getters never return `null`. Unavailable values return `''`, except these
documented locale defaults:

| Getter | Default |
| --- | --- |
| `languageCode` | `en` |
| `languageCode3` | `eng` |
| `languageTag` | `en` |
| `languageScriptCode` | `''` |
| `countryCode` | `US` |
| `countryCode3` | `USA` |
| `locale` | `en` |

Integer getters return `0`, boolean getters return `false`, and list getters
return an empty list when native values are unavailable.

Disk sizes are bytes. RAM sizes are MiB; iOS reports `0` for
`availableRamSize`, because iOS has no supported system-wide available-memory
API.

Local-ID write, delete, and reset methods throw a `StateError` when the native
secure store cannot complete the requested change. This prevents an in-memory
value from being reported as persisted when it is not.

## Publishing

Before publishing from this directory, run:

```sh
flutter test
flutter analyze
flutter pub publish --dry-run
```
