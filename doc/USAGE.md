# app_info_utils 使用说明

`app_info_utils` 是一个 Flutter 插件，用于在 iOS 和 Android 上统一读取应用信息、设备信息、系统信息、语言地区、时区和常用标识符。

当前推荐入口是：

```dart
AppInfoUtils.instance
```

## 安装

```yaml
dependencies:
  app_info_utils: ^0.1.4
```

导入：

```dart
import 'package:app_info_utils/app_info_utils.dart';
```

## 推荐用法

大多数场景不需要手动调用 `init()`，直接读取即可：

```dart
final model = AppInfoUtils.instance.deviceModel;
final appName = AppInfoUtils.instance.appName;
final version = AppInfoUtils.instance.version;
final packageName = AppInfoUtils.instance.packageName;
final deviceId = AppInfoUtils.instance.deviceId;
final countryCode = AppInfoUtils.instance.countryCode;
final timeZone = AppInfoUtils.instance.timeZone;
```

如果插件还没有初始化，第一次读取同步 getter 时会自动触发后台初始化。首次读取可能先返回默认值，后续读取会返回缓存到的原生值。

## 显式初始化

如果希望在 App 启动阶段主动预加载，可以显式调用 `init()`：

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final initialized = await AppInfoUtils.instance.init();
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
final info = await AppInfoUtils.instance.ready;

final model = info.deviceModel;
final appName = info.appName;
```

`ready` 会等待初始化完成，然后返回 `AppInfoUtils.instance`。

## 刷新数据

手动刷新全部信息：

```dart
final refreshed = await AppInfoUtils.instance.refresh();
```

刷新广告标识符：

```dart
await AppInfoUtils.instance.refreshAdvertisingId();
```

刷新设备标识符：

```dart
await AppInfoUtils.instance.refreshDeviceId();
```

重置主本地安全 ID：

```dart
await AppInfoUtils.instance.resetLocalId();
```

插件在完成初始化后会监听 App 生命周期。当 App 回到前台时，会自动静默刷新一次原生信息。

## 本地安全 ID

插件提供两个本地安全 ID：

```dart
AppInfoUtils.instance.primaryLocalId;
AppInfoUtils.instance.secondaryLocalId;
```

两个值都由原生 UUID 直接生成。Android 使用 Android KeyStore + RSA OAEP + AES-GCM 加密后保存到专用 SharedPreferences；iOS 使用 Keychain 和 `kSecAttrAccessibleWhenUnlocked` 保存。Android 和 iOS 会各自独立生成，不要求两个平台的值一致。

默认存储 namespace 会优先使用 Android `context.packageName` 或 iOS `Bundle.main.bundleIdentifier`。如果原生 namespace 暂时不可用，可以传入兜底 namespace；同一平台内如果后续两个 namespace 都可用，会把同一个值同步到所有候选 key，避免切换 key 后读到不同 ID。

```dart
await AppInfoUtils.instance.init(
  localIdStorageOptions: const LocalIdStorageOptions(
    fallbackNamespace: 'my_app',
  ),
);
```

统一操作方法通过 `LocalIdSlot` 区分主/副 ID：

```dart
final primary = await AppInfoUtils.instance.readLocalId();
final secondary = await AppInfoUtils.instance.readLocalId(
  slot: LocalIdSlot.secondary,
);

await AppInfoUtils.instance.writeLocalId('custom-id');
final exists = await AppInfoUtils.instance.containsLocalId();
await AppInfoUtils.instance.deleteLocalId();
final newPrimary = await AppInfoUtils.instance.resetLocalId();
final all = await AppInfoUtils.instance.resetAllLocalIds();
```

## iOS IDFA 和 ATT 授权

`init()` 不会主动弹出 ATT 授权弹窗，只会在已经授权的情况下读取 IDFA。

需要请求 IDFA 权限时调用：

```dart
final result = await AppInfoUtils.instance.requestIdfaAuthorization();

if (result.isSuccess) {
  final idfa = result.idfa;
  final cachedIdfa = AppInfoUtils.instance.idfa;
  final advertisingId = AppInfoUtils.instance.advertisingId;
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
AppInfoUtils.instance.appName;
AppInfoUtils.instance.packageName;
AppInfoUtils.instance.version;
AppInfoUtils.instance.buildNumber;
AppInfoUtils.instance.buildSignature;
AppInfoUtils.instance.installerStore;
AppInfoUtils.instance.installTime;
AppInfoUtils.instance.updateTime;
```

### 设备和系统信息

```dart
AppInfoUtils.instance.deviceModel;
AppInfoUtils.instance.platform;
AppInfoUtils.instance.osVersion;
AppInfoUtils.instance.systemName;
AppInfoUtils.instance.deviceName;
AppInfoUtils.instance.isPhysicalDevice;
AppInfoUtils.instance.freeDiskSize;
AppInfoUtils.instance.totalDiskSize;
AppInfoUtils.instance.physicalRamSize;
AppInfoUtils.instance.availableRamSize;
```

### 语言、地区和时区

```dart
AppInfoUtils.instance.languageCode;
AppInfoUtils.instance.languageCode3;
AppInfoUtils.instance.countryCode;
AppInfoUtils.instance.countryCode3;
AppInfoUtils.instance.locale;
AppInfoUtils.instance.timeZone;
AppInfoUtils.instance.utcOffsetSeconds;
```

### 标识符

```dart
AppInfoUtils.instance.advertisingId;
AppInfoUtils.instance.deviceId;
AppInfoUtils.instance.idfa;
AppInfoUtils.instance.idfv;
AppInfoUtils.instance.gaid;
AppInfoUtils.instance.androidId;
AppInfoUtils.instance.asid;
AppInfoUtils.instance.primaryLocalId;
AppInfoUtils.instance.secondaryLocalId;
```

## Android 专属字段

```dart
AppInfoUtils.instance.androidBoard;
AppInfoUtils.instance.androidBootloader;
AppInfoUtils.instance.androidBrand;
AppInfoUtils.instance.androidDevice;
AppInfoUtils.instance.androidDisplay;
AppInfoUtils.instance.androidFingerprint;
AppInfoUtils.instance.androidHardware;
AppInfoUtils.instance.androidHost;
AppInfoUtils.instance.androidId;
AppInfoUtils.instance.androidProduct;
AppInfoUtils.instance.androidSupported32BitAbis;
AppInfoUtils.instance.androidSupported64BitAbis;
AppInfoUtils.instance.androidSupportedAbis;
AppInfoUtils.instance.androidTags;
AppInfoUtils.instance.androidType;
AppInfoUtils.instance.androidSystemFeatures;
AppInfoUtils.instance.androidIsLowRamDevice;
AppInfoUtils.instance.androidBaseOs;
AppInfoUtils.instance.androidSdkInt;
AppInfoUtils.instance.androidRelease;
AppInfoUtils.instance.androidCodename;
AppInfoUtils.instance.androidIncremental;
AppInfoUtils.instance.androidPreviewSdkInt;
AppInfoUtils.instance.androidSecurityPatch;
```

## iOS 专属字段

```dart
AppInfoUtils.instance.iosModelName;
AppInfoUtils.instance.iosLocalizedModel;
AppInfoUtils.instance.isiOSAppOnMac;
AppInfoUtils.instance.isiOSAppOnVision;
AppInfoUtils.instance.iosUtsnameSysname;
AppInfoUtils.instance.iosUtsnameNodename;
AppInfoUtils.instance.iosUtsnameRelease;
AppInfoUtils.instance.iosUtsnameVersion;
AppInfoUtils.instance.iosUtsnameMachine;
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
final data = AppInfoUtils.instance.data;
```

返回值是不可修改的 `Map<String, dynamic>`。

## CocoaPods 和 Swift Package Manager

iOS 侧同时支持 CocoaPods 和 Swift Package Manager。

插件包含 `PrivacyInfo.xcprivacy`，用于声明 iOS required reason API 使用原因。CocoaPods 和 SPM 都会打包同一份隐私清单。

## 兼容入口

`AppInfoUtils()` 仍然保留为 singleton factory，因此以下写法依然可用：

```dart
final info = AppInfoUtils();
final model = info.deviceModel;
```

不过新代码推荐统一使用：

```dart
AppInfoUtils.instance
```
