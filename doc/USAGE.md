# app_info_helper 使用说明

`app_info_helper` 是一个 Flutter 插件，用于在 iOS 和 Android 上统一读取应用信息、设备信息、系统信息、语言地区、时区和常用标识符。

当前推荐入口是：

```dart
AppInfoHelper.instance
```

## 安装

```yaml
dependencies:
  app_info_helper: ^0.1.3
```

导入：

```dart
import 'package:app_info_helper/app_info_helper.dart';
```

## 推荐用法

大多数场景不需要手动调用 `init()`，直接读取即可：

```dart
final model = AppInfoHelper.instance.deviceModel;
final appName = AppInfoHelper.instance.appName;
final version = AppInfoHelper.instance.version;
final packageName = AppInfoHelper.instance.packageName;
final deviceId = AppInfoHelper.instance.deviceId;
final countryCode = AppInfoHelper.instance.countryCode;
final timeZone = AppInfoHelper.instance.timeZone;
```

如果插件还没有初始化，第一次读取同步 getter 时会自动触发后台初始化。首次读取可能先返回默认值，后续读取会返回缓存到的原生值。

## 显式初始化

如果希望在 App 启动阶段主动预加载，可以显式调用 `init()`：

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final initialized = await AppInfoHelper.instance.init();
  if (!initialized) {
    // 原生信息暂时不可用，getter 仍会返回默认值。
  }

  runApp(const MyApp());
}
```

`init()` 成功执行一次后，数据会缓存在内存中，后续读取 getter 不会重复请求原生数据。

`init()` 返回 `bool`：

- `true`：原生数据加载成功
- `false`：原生数据不可用、返回空数据或读取失败

原生 channel 调用失败时，`init()` 不会向外抛异常。

如果多个地方同时调用 `init()`，内部会复用同一个初始化 Future，不会重复发起多次原生请求。

## 等待已加载实例

如果某个位置必须保证读取到的是已加载后的原生值，可以使用 `ready`：

```dart
final info = await AppInfoHelper.instance.ready;

final model = info.deviceModel;
final appName = info.appName;
```

`ready` 会等待初始化完成，然后返回 `AppInfoHelper.instance`。

## 刷新数据

手动刷新全部信息：

```dart
final refreshed = await AppInfoHelper.instance.refresh();
```

刷新广告标识符：

```dart
await AppInfoHelper.instance.refreshAdvertisingId();
```

刷新设备标识符：

```dart
await AppInfoHelper.instance.refreshDeviceId();
```

重置本地 UUID：

```dart
await AppInfoHelper.instance.resetLocalUuid();
```

插件在完成初始化后会监听 App 生命周期。当 App 回到前台时，会自动静默刷新一次原生信息。

## iOS IDFA 和 ATT 授权

`init()` 不会主动弹出 ATT 授权弹窗，只会在已经授权的情况下读取 IDFA。

需要请求 IDFA 权限时调用：

```dart
final result = await AppInfoHelper.instance.requestIdfaAuthorization();

if (result.isSuccess) {
  final idfa = result.idfa;
  final cachedIdfa = AppInfoHelper.instance.idfa;
  final advertisingId = AppInfoHelper.instance.advertisingId;
} else {
  final failure = result.failure;
}
```

调用成功后，插件会把返回的 IDFA 数据合并到内部缓存中，不需要额外再调用 `refresh()`。

iOS 宿主 App 需要在 `ios/Runner/Info.plist` 中添加：

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier is used to provide more relevant content and advertising.</string>
```

## 常用字段

### 应用信息

```dart
AppInfoHelper.instance.appName;
AppInfoHelper.instance.packageName;
AppInfoHelper.instance.version;
AppInfoHelper.instance.buildNumber;
AppInfoHelper.instance.buildSignature;
AppInfoHelper.instance.installerStore;
AppInfoHelper.instance.installTime;
AppInfoHelper.instance.updateTime;
```

### 设备和系统信息

```dart
AppInfoHelper.instance.deviceModel;
AppInfoHelper.instance.platform;
AppInfoHelper.instance.osVersion;
AppInfoHelper.instance.systemName;
AppInfoHelper.instance.deviceName;
AppInfoHelper.instance.isPhysicalDevice;
AppInfoHelper.instance.freeDiskSize;
AppInfoHelper.instance.totalDiskSize;
AppInfoHelper.instance.physicalRamSize;
AppInfoHelper.instance.availableRamSize;
```

### 语言、地区和时区

```dart
AppInfoHelper.instance.languageCode;
AppInfoHelper.instance.languageCode3;
AppInfoHelper.instance.countryCode;
AppInfoHelper.instance.countryCode3;
AppInfoHelper.instance.locale;
AppInfoHelper.instance.timeZone;
AppInfoHelper.instance.utcOffsetSeconds;
```

### 标识符

```dart
AppInfoHelper.instance.advertisingId;
AppInfoHelper.instance.deviceId;
AppInfoHelper.instance.idfa;
AppInfoHelper.instance.idfv;
AppInfoHelper.instance.gaid;
AppInfoHelper.instance.androidId;
AppInfoHelper.instance.asid;
AppInfoHelper.instance.localUuid;
```

## Android 专属字段

```dart
AppInfoHelper.instance.androidBoard;
AppInfoHelper.instance.androidBootloader;
AppInfoHelper.instance.androidBrand;
AppInfoHelper.instance.androidDevice;
AppInfoHelper.instance.androidDisplay;
AppInfoHelper.instance.androidFingerprint;
AppInfoHelper.instance.androidHardware;
AppInfoHelper.instance.androidHost;
AppInfoHelper.instance.androidId;
AppInfoHelper.instance.androidProduct;
AppInfoHelper.instance.androidSupported32BitAbis;
AppInfoHelper.instance.androidSupported64BitAbis;
AppInfoHelper.instance.androidSupportedAbis;
AppInfoHelper.instance.androidTags;
AppInfoHelper.instance.androidType;
AppInfoHelper.instance.androidSystemFeatures;
AppInfoHelper.instance.androidIsLowRamDevice;
AppInfoHelper.instance.androidBaseOs;
AppInfoHelper.instance.androidSdkInt;
AppInfoHelper.instance.androidRelease;
AppInfoHelper.instance.androidCodename;
AppInfoHelper.instance.androidIncremental;
AppInfoHelper.instance.androidPreviewSdkInt;
AppInfoHelper.instance.androidSecurityPatch;
```

## iOS 专属字段

```dart
AppInfoHelper.instance.iosModelName;
AppInfoHelper.instance.iosLocalizedModel;
AppInfoHelper.instance.isiOSAppOnMac;
AppInfoHelper.instance.isiOSAppOnVision;
AppInfoHelper.instance.iosUtsnameSysname;
AppInfoHelper.instance.iosUtsnameNodename;
AppInfoHelper.instance.iosUtsnameRelease;
AppInfoHelper.instance.iosUtsnameVersion;
AppInfoHelper.instance.iosUtsnameMachine;
```

## 默认值规则

所有字符串 getter 都不会返回 `null`。不可用时返回空字符串，但以下字段有固定默认值：

| Getter | 默认值 |
| --- | --- |
| `languageCode` | `en` |
| `languageCode3` | `eng` |
| `countryCode` | `US` |
| `countryCode3` | `USA` |
| `locale` | `en_US` |

数字 getter 不可用时返回 `0`，布尔 getter 不可用时返回 `false`，列表 getter 不可用时返回空列表。

## 原始数据

如果需要读取完整原始 Map：

```dart
final data = AppInfoHelper.instance.data;
```

返回值是不可修改的 `Map<String, dynamic>`。

## CocoaPods 和 Swift Package Manager

iOS 侧同时支持 CocoaPods 和 Swift Package Manager。

插件包含 `PrivacyInfo.xcprivacy`，用于声明 iOS required reason API 使用原因。CocoaPods 和 SPM 都会打包同一份隐私清单。

## 兼容入口

`AppInfoHelper()` 仍然保留为 singleton factory，因此以下写法依然可用：

```dart
final info = AppInfoHelper();
final model = info.deviceModel;
```

不过新代码推荐统一使用：

```dart
AppInfoHelper.instance
```
