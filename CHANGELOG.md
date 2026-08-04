## 0.2.0

- **Breaking:** Remove the GetX dependency and the
  `event_bus_manager_getx.dart` / `EventManagerGetxMixin` APIs.
- Simplify the example app to use Flutter's built-in `MaterialApp` and State
  lifecycle support.

## 0.1.6

- Read iOS language metadata from the device's preferred-language list instead
  of the app-resolved locale, so an unsupported app localization does not report
  a different system language.
- Add `languageTag` for the BCP-47 language and script identifier without a
  region, such as `zh-Hans`, and make `locale` return the full preferred
  language identifier.
- Add `languageScriptCode` for the ISO 15924 script identifier, such as
  `Hans`.
- Expand iOS built-in ISO mappings to all 183 ISO 639-1 language codes and all
  249 currently assigned ISO 3166-1 country and territory codes.
- Make Android `getAll` refresh advertising and App Set identifiers too, so
  initialization and foreground-resume refreshes replace every cached field.
- Expanded README and usage docs with detailed feature and platform-field
  guidance.

## 0.1.5

- Renamed the package to `x_app_utils` and the public entry point to
  `XAppUtils`.
- Corrected the GitHub homepage, repository, and issue-tracker links used by
  pub.dev to point to `jimlonger/app_info_helper`.
- Made Android advertising ID and App Set ID reads explicit, on-demand calls.
  The plugin no longer injects the `AD_ID` permission into host apps.
- Report `0` for unavailable iOS available RAM instead of reporting total RAM.
- Report unknown iOS ISO-3 locale codes as unavailable instead of a false US or
  English value.
- Surface secure local-ID write, delete, and reset failures instead of updating
  the in-memory cache as if persistence had succeeded.

## 0.1.4

- Renamed the package to `x_app_utils` and the public entry point to
  `XAppUtils`.
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

- Added `XAppUtils.instance` as the recommended singleton entry point.
- Added automatic lazy initialization when synchronous getters are first read.
- Added `XAppUtils.instance.ready` for callers that need to await loaded native values.
- Updated usage documentation while keeping explicit `init()` support.

## 0.1.0

- Initial release with unified app, device, locale, timezone, and identifier APIs for iOS and Android.
- Added cached synchronous getters after startup initialization.
- Added iOS ATT authorization helper for IDFA access.
- Added Android advertising ID, App Set ID, Android ID, and local UUID fallbacks.
