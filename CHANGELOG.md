## 0.1.4

- Replaced the previous local UUID with secure `primaryLocalId` and
  `secondaryLocalId` values.
- Added slot-based local ID read, write, contains, delete, and reset APIs.
- Added Android KeyStore + RSA OAEP + AES-GCM storage for local IDs.
- Added iOS Keychain storage for local IDs.

## 0.1.3

- Changed `init()` to return `true` when native values load successfully and `false` when unavailable.
- Changed `refresh()` to return whether the full native data refresh succeeded.
- Documented non-throwing initialization failure handling.

## 0.1.2

- Added a complete Chinese usage guide in `doc/USAGE.md`.
- Linked the extended usage guide from the README.
- Updated installation examples to reference `^0.1.3`.

## 0.1.1

- Added `AppInfoHelper.instance` as the recommended singleton entry point.
- Added automatic lazy initialization when synchronous getters are first read.
- Added `AppInfoHelper.instance.ready` for callers that need to await loaded native values.
- Updated usage documentation while keeping explicit `init()` support.

## 0.1.0

- Initial release with unified app, device, locale, timezone, and identifier APIs for iOS and Android.
- Added cached synchronous getters after startup initialization.
- Added iOS ATT authorization helper for IDFA access.
- Added Android advertising ID, App Set ID, Android ID, and local UUID fallbacks.
