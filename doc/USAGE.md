# x_app_utils 使用说明

`x_app_utils` 是一个 Flutter 插件，用于在 iOS 和 Android 上统一读取应用信息、设备信息、系统信息、语言地区、时区和常用标识符。

当前推荐入口是：

```dart
XAppUtils.instance
```

## 安装

```yaml
dependencies:
  x_app_utils: ^0.1.5
```

导入：

```dart
import 'package:x_app_utils/x_app_utils.dart';
```

## 推荐用法

大多数场景不需要手动调用 `init()`，直接读取即可：

```dart
final model = XAppUtils.instance.deviceModel;
final appName = XAppUtils.instance.appName;
final version = XAppUtils.instance.version;
final packageName = XAppUtils.instance.packageName;
final deviceId = XAppUtils.instance.deviceId;
final countryCode = XAppUtils.instance.countryCode;
final timeZone = XAppUtils.instance.timeZone;
```

如果插件还没有初始化，第一次读取同步 getter 时会自动触发后台初始化。首次读取可能先返回默认值，后续读取会返回缓存到的原生值。

## 显式初始化

如果希望在 App 启动阶段主动预加载，可以显式调用 `init()`：

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final initialized = await XAppUtils.instance.init();
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
final info = await XAppUtils.instance.ready;

final model = info.deviceModel;
final appName = info.appName;
```

`ready` 会等待初始化完成，然后返回 `XAppUtils.instance`。

## 刷新数据

手动刷新全部信息：

```dart
final refreshed = await XAppUtils.instance.refresh();
```

刷新广告标识符：

```dart
await XAppUtils.instance.refreshAdvertisingId();
```

刷新设备标识符：

```dart
await XAppUtils.instance.refreshDeviceId();
```

重置主本地安全 ID：

```dart
await XAppUtils.instance.resetLocalId();
```

插件在完成初始化后会监听 App 生命周期。当 App 回到前台时，会自动静默刷新一次原生信息。

## 广告标识符与 Android 隐私

`init()` 和前台自动刷新不会读取广告标识符。只有在业务已取得所需用户同意后，才按需读取 Google 广告 ID：

```dart
await XAppUtils.instance.refreshAdvertisingId();
```

插件不会自动向宿主 App 合并 `AD_ID` 权限。若使用 `refreshAdvertisingId()`，请在宿主的
`android/app/src/main/AndroidManifest.xml` 中声明权限，并按实际数据使用情况完成 Google Play 的 Data safety 信息：

```xml
<uses-permission android:name="com.google.android.gms.permission.AD_ID" />
```

`refreshDeviceId()` 会按需读取 Android App Set ID。服务不可用、权限缺失或用户设置不允许时，相应标识符会返回空字符串。

## 本地安全 ID

插件提供两个本地安全 ID：

```dart
XAppUtils.instance.primaryLocalId;
XAppUtils.instance.secondaryLocalId;
```

两个值都由原生 UUID 直接生成。Android 使用 Android KeyStore + RSA OAEP + AES-GCM 加密后保存到专用 SharedPreferences；iOS 使用 Keychain 和 `kSecAttrAccessibleWhenUnlocked` 保存。Android 和 iOS 会各自独立生成，不要求两个平台的值一致。

写入、删除和重置本地 ID 时，如果原生安全存储无法完成操作，方法会抛出 `StateError`；不会仅更新内存缓存而误报已持久化。

默认存储 namespace 会优先使用 Android `context.packageName` 或 iOS `Bundle.main.bundleIdentifier`。如果原生 namespace 暂时不可用，可以传入兜底 namespace；同一平台内如果后续两个 namespace 都可用，会把同一个值同步到所有候选 key，避免切换 key 后读到不同 ID。

```dart
await XAppUtils.instance.init(
  localIdStorageOptions: const LocalIdStorageOptions(
    fallbackNamespace: 'my_app',
  ),
);
```

统一操作方法通过 `LocalIdSlot` 区分主/副 ID：

```dart
final primary = await XAppUtils.instance.readLocalId();
final secondary = await XAppUtils.instance.readLocalId(
  slot: LocalIdSlot.secondary,
);

await XAppUtils.instance.writeLocalId('custom-id');
final exists = await XAppUtils.instance.containsLocalId();
await XAppUtils.instance.deleteLocalId();
final newPrimary = await XAppUtils.instance.resetLocalId();
final all = await XAppUtils.instance.resetAllLocalIds();
```

## iOS IDFA 和 ATT 授权

`init()` 不会主动弹出 ATT 授权弹窗，只会在已经授权的情况下读取 IDFA。

需要请求 IDFA 权限时调用：

```dart
final result = await XAppUtils.instance.requestIdfaAuthorization();

if (result.isSuccess) {
  final idfa = result.idfa;
  final cachedIdfa = XAppUtils.instance.idfa;
  final advertisingId = XAppUtils.instance.advertisingId;
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
XAppUtils.instance.appName;
XAppUtils.instance.packageName;
XAppUtils.instance.version;
XAppUtils.instance.buildNumber;
XAppUtils.instance.buildSignature;
XAppUtils.instance.installerStore;
XAppUtils.instance.installTime;
XAppUtils.instance.updateTime;
```

### 设备和系统信息

```dart
XAppUtils.instance.deviceModel;
XAppUtils.instance.platform;
XAppUtils.instance.osVersion;
XAppUtils.instance.systemName;
XAppUtils.instance.deviceName;
XAppUtils.instance.isPhysicalDevice;
XAppUtils.instance.freeDiskSize;
XAppUtils.instance.totalDiskSize;
XAppUtils.instance.physicalRamSize;
XAppUtils.instance.availableRamSize;
```

### 语言、地区和时区

```dart
XAppUtils.instance.languageCode;
XAppUtils.instance.languageCode3;
XAppUtils.instance.countryCode;
XAppUtils.instance.countryCode3;
XAppUtils.instance.locale;
XAppUtils.instance.timeZone;
XAppUtils.instance.utcOffsetSeconds;
```

### 标识符

```dart
XAppUtils.instance.advertisingId;
XAppUtils.instance.deviceId;
XAppUtils.instance.idfa;
XAppUtils.instance.idfv;
XAppUtils.instance.gaid;
XAppUtils.instance.androidId;
XAppUtils.instance.asid;
XAppUtils.instance.primaryLocalId;
XAppUtils.instance.secondaryLocalId;
```

## Android 专属字段

```dart
XAppUtils.instance.androidBoard;
XAppUtils.instance.androidBootloader;
XAppUtils.instance.androidBrand;
XAppUtils.instance.androidDevice;
XAppUtils.instance.androidDisplay;
XAppUtils.instance.androidFingerprint;
XAppUtils.instance.androidHardware;
XAppUtils.instance.androidHost;
XAppUtils.instance.androidId;
XAppUtils.instance.androidProduct;
XAppUtils.instance.androidSupported32BitAbis;
XAppUtils.instance.androidSupported64BitAbis;
XAppUtils.instance.androidSupportedAbis;
XAppUtils.instance.androidTags;
XAppUtils.instance.androidType;
XAppUtils.instance.androidSystemFeatures;
XAppUtils.instance.androidIsLowRamDevice;
XAppUtils.instance.androidBaseOs;
XAppUtils.instance.androidSdkInt;
XAppUtils.instance.androidRelease;
XAppUtils.instance.androidCodename;
XAppUtils.instance.androidIncremental;
XAppUtils.instance.androidPreviewSdkInt;
XAppUtils.instance.androidSecurityPatch;
```

## iOS 专属字段

```dart
XAppUtils.instance.iosModelName;
XAppUtils.instance.iosLocalizedModel;
XAppUtils.instance.isiOSAppOnMac;
XAppUtils.instance.isiOSAppOnVision;
XAppUtils.instance.iosUtsnameSysname;
XAppUtils.instance.iosUtsnameNodename;
XAppUtils.instance.iosUtsnameRelease;
XAppUtils.instance.iosUtsnameVersion;
XAppUtils.instance.iosUtsnameMachine;
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
final data = XAppUtils.instance.data;
```

返回值是不可修改的 `Map<String, dynamic>`。

## CocoaPods 和 Swift Package Manager

iOS 侧同时支持 CocoaPods 和 Swift Package Manager。

插件包含 `PrivacyInfo.xcprivacy`，用于声明 iOS required reason API 使用原因。CocoaPods 和 SPM 都会打包同一份隐私清单。

## 兼容入口

`XAppUtils()` 仍然保留为 singleton factory，因此以下写法依然可用：

```dart
final info = XAppUtils();
final model = info.deviceModel;
```

不过新代码推荐统一使用：

```dart
XAppUtils.instance
```
