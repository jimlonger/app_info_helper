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
