# app_info_helper

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

## Installation

```yaml
dependencies:
  app_info_helper: ^0.1.4
```

Then import the package:

```dart
import 'package:app_info_helper/app_info_helper.dart';
```

## Usage

For a complete Chinese integration guide, see
[doc/USAGE.md](doc/USAGE.md).

Read values from the shared instance:

```dart
final info = AppInfoHelper.instance;

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

`AppInfoHelper.instance` is the recommended entry point. `AppInfoHelper()` is
kept as a singleton factory for compatibility.

You may also initialize explicitly during app startup when you want to preload
native values:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialized = await AppInfoHelper.instance.init();
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
final info = await AppInfoHelper.instance.ready;
final model = info.deviceModel;
```

## Refreshing Values

```dart
final refreshed = await AppInfoHelper.instance.refresh();
await AppInfoHelper.instance.refreshAdvertisingId();
await AppInfoHelper.instance.refreshDeviceId();
await AppInfoHelper.instance.resetLocalId();
```

The plugin also refreshes cached values when the app returns to the foreground.

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
await AppInfoHelper.instance.init(
  localIdStorageOptions: const LocalIdStorageOptions(
    fallbackNamespace: 'my_app',
  ),
);
```

Manage either local ID through a single slot-based API:

```dart
final primary = await AppInfoHelper.instance.readLocalId();
final secondary = await AppInfoHelper.instance.readLocalId(
  slot: LocalIdSlot.secondary,
);

await AppInfoHelper.instance.writeLocalId('custom-id');
final exists = await AppInfoHelper.instance.containsLocalId();
await AppInfoHelper.instance.deleteLocalId();
final newPrimary = await AppInfoHelper.instance.resetLocalId();
```

## iOS IDFA and ATT

`init()` never shows the ATT prompt. It only reads IDFA when tracking permission
has already been granted.

To request ATT authorization:

```dart
final result = await AppInfoHelper.instance.requestIdfaAuthorization();

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
| `countryCode` | `US` |
| `countryCode3` | `USA` |
| `locale` | `en_US` |

Integer getters return `0`, boolean getters return `false`, and list getters
return an empty list when native values are unavailable.

## Publishing

Before publishing from this directory, run:

```sh
flutter test
flutter analyze
flutter pub publish --dry-run
```
