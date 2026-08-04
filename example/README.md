# x_app_utils example

Runnable Android and iOS example for `x_app_utils` and `EventBusManager`.

It includes separate pages for Flutter `State` and ordinary service objects,
plus an event log and platform information on the home page.

## Run

```sh
flutter pub get
flutter run
```

The iOS Runner uses CocoaPods and has an iOS 15.0 deployment target, matching
the plugin's native requirement. Swift Package Manager is disabled only for
this example because the local repository directory (`app_info_helper`) differs
from the published Dart package name (`x_app_utils`), which currently causes
Flutter SwiftPM local-package identity resolution to fail.

## Verify

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
```
