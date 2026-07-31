import AdSupport
import AppTrackingTransparency
import Flutter
import Security
import UIKit
import MachO

public final class XAppUtilsPlugin: NSObject, FlutterPlugin {
  private let localIds = SecureLocalIdStorage()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "x_app_utils", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(XAppUtilsPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let options = localIdOptions(call)
    switch call.method {
    case "getAll": result(all(options))
    case "refreshAdvertisingId": result(identifiers(options))
    case "refreshDeviceId": result(identifiers(options))
    case "readLocalId": result(localIds.read(slot(call), options: options).map)
    case "writeLocalId": result(localIds.write(slot(call), value: value(call), options: options).map)
    case "deleteLocalId": result(["success": localIds.delete(slot(call), options: options)])
    case "containsLocalId": result(["containsKey": localIds.contains(slot(call), options: options), "localIdsPersisted": true])
    case "resetLocalId": result(localIds.reset(slot(call), options: options).map)
    case "readAllLocalIds": result(localIds.readAll(options).map)
    case "deleteAllLocalIds": result(["success": localIds.deleteAll(options)])
    case "resetAllLocalIds": result(localIds.resetAll(options).map)
    case "requestIdfaAuthorization": requestIdfa(result, options)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func all(_ options: LocalIdOptions) -> [String: Any] {
    var values = common()
    values.merge(app()) { _, new in new }
    values.merge(locale()) { _, new in new }
    values.merge(identifiers(options)) { _, new in new }
    return values
  }

  private func common() -> [String: Any] {
    let d = UIDevice.current
    let disk = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
    return [
      "deviceModel": machine(), "platform": d.model, "osVersion": d.systemVersion,
      "systemName": d.systemName, "deviceName": d.name, "isPhysicalDevice": !isSimulator,
      "freeDiskSize": (disk?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0,
      "totalDiskSize": (disk?[.systemSize] as? NSNumber)?.int64Value ?? 0,
      "physicalRamSize": Int64(ProcessInfo.processInfo.physicalMemory / 1_048_576),
      // iOS does not expose a supported process-wide available-memory API.
      "availableRamSize": 0,
      "iosModelName": machine(), "iosLocalizedModel": d.localizedModel,
      "isiOSAppOnMac": isiOSAppOnMac, "isiOSAppOnVision": isiOSAppOnVision,
      "iosUtsnameSysname": uts().sysname, "iosUtsnameNodename": uts().nodename,
      "iosUtsnameRelease": uts().release, "iosUtsnameVersion": uts().version,
      "iosUtsnameMachine": uts().machine,
      // Android-specific values retain their documented empty/default values.
      "androidBoard": "", "androidBootloader": "", "androidBrand": "", "androidDevice": "", "androidDisplay": "", "androidFingerprint": "", "androidHardware": "", "androidHost": "", "androidId": "", "androidProduct": "", "androidSupported32BitAbis": [], "androidSupported64BitAbis": [], "androidSupportedAbis": [], "androidTags": "", "androidType": "", "androidSystemFeatures": [], "androidIsLowRamDevice": false, "androidBaseOs": "", "androidSdkInt": 0, "androidRelease": "", "androidCodename": "", "androidIncremental": "", "androidPreviewSdkInt": 0, "androidSecurityPatch": ""
    ]
  }

  private func app() -> [String: Any] {
    let b = Bundle.main
    return ["appName": b.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? b.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "",
            "packageName": b.bundleIdentifier ?? "", "version": b.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            "buildNumber": b.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "", "buildSignature": "", "installerStore": "", "installTime": 0, "updateTime": 0]
  }

  private func locale() -> [String: Any] {
    let l = Locale.current; let country = l.regionCode ?? "US"; let language = l.languageCode ?? "en"; let tz = TimeZone.current
    return ["languageCode": language, "languageCode3": ISO639.alpha3(language), "countryCode": country, "countryCode3": ISO3166.alpha3(country), "locale": l.identifier.isEmpty ? "en_US" : l.identifier, "timeZone": tz.identifier, "utcOffsetSeconds": tz.secondsFromGMT()]
  }

  private func identifiers(_ options: LocalIdOptions) -> [String: Any] {
    let ids = localIds.readAll(options)
    let idfv = UIDevice.current.identifierForVendor?.uuidString ?? ""
    let idfa = currentIdfa()
    return ["idfa": idfa, "andi": "", "aifa": "", "gaid": "", "aaid": "", "oaid": "", "asid": "", "idfv": idfv, "primaryLocalId": ids.primary, "secondaryLocalId": ids.secondary, "localIdsPersisted": ids.persisted, "advertisingId": idfa, "deviceId": idfv.isEmpty ? ids.primary : idfv]
  }

  private func requestIdfa(_ result: @escaping FlutterResult, _ options: LocalIdOptions) {
    guard #available(iOS 14, *) else { result(failure("unavailable", options)); return }
    ATTrackingManager.requestTrackingAuthorization { status in
      let idfa = status == .authorized ? self.currentIdfa() : ""
      if !idfa.isEmpty { var data = self.identifiers(options); data["isSuccess"] = true; data["failure"] = "none"; result(data); return }
      let failureCode = status == .denied ? "denied" : status == .restricted ? "restricted" : "invalidIdfa"
      result(self.failure(failureCode, options))
    }
  }

  private func currentIdfa() -> String {
    guard #available(iOS 14, *), ATTrackingManager.trackingAuthorizationStatus == .authorized else { return "" }
    let value = ASIdentifierManager.shared().advertisingIdentifier.uuidString
    return value == "00000000-0000-0000-0000-000000000000" ? "" : value
  }
  private func failure(_ code: String, _ options: LocalIdOptions = LocalIdOptions()) -> [String: Any] { var data = identifiers(options); data["isSuccess"] = false; data["failure"] = code; return data }
  private func localIdOptions(_ call: FlutterMethodCall) -> LocalIdOptions {
    guard let args = call.arguments as? [String: Any], let options = args["localIdStorageOptions"] as? [String: Any] else { return LocalIdOptions() }
    return LocalIdOptions(fallbackNamespace: options["fallbackNamespace"] as? String, primaryKey: options["primaryKey"] as? String, secondaryKey: options["secondaryKey"] as? String)
  }
  private func slot(_ call: FlutterMethodCall) -> LocalIdSlot {
    guard let args = call.arguments as? [String: Any], args["slot"] as? String == "secondary" else { return .primary }
    return .secondary
  }
  private func value(_ call: FlutterMethodCall) -> String {
    guard let args = call.arguments as? [String: Any], let value = args["value"] as? String else { return "" }
    return value
  }
  private var isSimulator: Bool {
    #if targetEnvironment(simulator)
      return true
    #else
      return false
    #endif
  }
  private var isiOSAppOnMac: Bool { if #available(iOS 14.0, *) { return ProcessInfo.processInfo.isiOSAppOnMac }; return false }
  // `isIOSAppOnVision` is visionOS-specific; iOS builds report false.
  private var isiOSAppOnVision: Bool { false }
  private func machine() -> String { uts().machine }
  private func uts() -> (sysname: String, nodename: String, release: String, version: String, machine: String) {
    var v = utsname(); uname(&v)
    func value<T>(_ field: T) -> String { withUnsafePointer(to: field) { $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: field)) { String(cString: $0) } } }
    return (value(v.sysname), value(v.nodename), value(v.release), value(v.version), value(v.machine))
  }
}

private enum LocalIdSlot { case primary, secondary }
private struct LocalIdOptions {
  let fallbackNamespace: String?
  let primaryKey: String?
  let secondaryKey: String?
  init(fallbackNamespace: String? = nil, primaryKey: String? = nil, secondaryKey: String? = nil) {
    self.fallbackNamespace = fallbackNamespace
    self.primaryKey = primaryKey
    self.secondaryKey = secondaryKey
  }
}
private struct LocalIdResult {
  let primary: String
  let secondary: String
  let persisted: Bool
  var map: [String: Any] { ["success": persisted, "primaryLocalId": primary, "secondaryLocalId": secondary, "localIdsPersisted": persisted] }
}

private final class SecureLocalIdStorage {
  func read(_ slot: LocalIdSlot, options: LocalIdOptions) -> LocalIdResult {
    readAll(options)
  }
  func readAll(_ options: LocalIdOptions) -> LocalIdResult {
    let primary = getOrCreate(.primary, options: options)
    let secondary = getOrCreate(.secondary, options: options)
    return LocalIdResult(primary: primary.value, secondary: secondary.value, persisted: primary.persisted && secondary.persisted)
  }
  func write(_ slot: LocalIdSlot, value: String, options: LocalIdOptions) -> LocalIdResult {
    let persisted = writeKeys(keys(slot, options: options), value: value)
    let all = readAll(options)
    switch slot {
    case .primary: return LocalIdResult(primary: value, secondary: all.secondary, persisted: persisted && all.persisted)
    case .secondary: return LocalIdResult(primary: all.primary, secondary: value, persisted: persisted && all.persisted)
    }
  }
  func reset(_ slot: LocalIdSlot, options: LocalIdOptions) -> LocalIdResult {
    guard delete(slot, options: options) else {
      let all = readAll(options)
      return LocalIdResult(primary: all.primary, secondary: all.secondary, persisted: false)
    }
    return write(slot, value: UUID().uuidString, options: options)
  }
  func resetAll(_ options: LocalIdOptions) -> LocalIdResult {
    guard deleteAll(options) else {
      let all = readAll(options)
      return LocalIdResult(primary: all.primary, secondary: all.secondary, persisted: false)
    }
    let primary = UUID().uuidString
    let secondary = UUID().uuidString
    let primarySaved = writeKeys(keys(.primary, options: options), value: primary)
    let secondarySaved = writeKeys(keys(.secondary, options: options), value: secondary)
    return LocalIdResult(primary: primary, secondary: secondary, persisted: primarySaved && secondarySaved)
  }
  func contains(_ slot: LocalIdSlot, options: LocalIdOptions) -> Bool {
    keys(slot, options: options).contains { readKey($0) != nil }
  }
  func delete(_ slot: LocalIdSlot, options: LocalIdOptions) -> Bool {
    keys(slot, options: options).allSatisfy { deleteKey($0) }
  }
  func deleteAll(_ options: LocalIdOptions) -> Bool {
    delete(.primary, options: options) && delete(.secondary, options: options)
  }

  private func getOrCreate(_ slot: LocalIdSlot, options: LocalIdOptions) -> (value: String, persisted: Bool) {
    let value = readPlain(slot, options: options) ?? UUID().uuidString
    return (value, writeKeys(keys(slot, options: options), value: value))
  }
  private func readPlain(_ slot: LocalIdSlot, options: LocalIdOptions) -> String? {
    for key in keys(slot, options: options) {
      if let value = readKey(key), !value.isEmpty { return value }
    }
    return nil
  }
  private func writeKeys(_ keys: [String], value: String) -> Bool {
    keys.map { writeKey($0, value: value) }.allSatisfy { $0 }
  }
  private func keys(_ slot: LocalIdSlot, options: LocalIdOptions) -> [String] {
    let explicit = slot == .primary ? options.primaryKey : options.secondaryKey
    if let explicit, !explicit.isEmpty { return [explicit] }
    let suffix = slot == .primary ? "primaryLocalId" : "secondaryLocalId"
    var namespaces = [String]()
    if let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty { namespaces.append(bundleId) }
    if let fallback = options.fallbackNamespace, !fallback.isEmpty { namespaces.append(fallback) }
    namespaces.append("x_app_utils")
    return Array(NSOrderedSet(array: namespaces).compactMap { $0 as? String }).map { "\($0).\(suffix)" }
  }
  private func query(_ key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service(key),
      kSecAttrAccount as String: key
    ]
  }
  private func service(_ key: String) -> String {
    key.split(separator: ".").dropLast().joined(separator: ".").isEmpty ? "x_app_utils.local_ids" : key.split(separator: ".").dropLast().joined(separator: ".")
  }
  private func readKey(_ key: String) -> String? {
    var q = query(key)
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: AnyObject?
    guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }
  private func writeKey(_ key: String, value: String) -> Bool {
    let data = Data(value.utf8)
    var q = query(key)
    let update = [kSecValueData as String: data]
    let status = SecItemUpdate(q as CFDictionary, update as CFDictionary)
    if status == errSecSuccess { return true }
    if status != errSecItemNotFound { return false }
    q[kSecValueData as String] = data
    q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
    return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
  }
  private func deleteKey(_ key: String) -> Bool {
    let status = SecItemDelete(query(key) as CFDictionary)
    return status == errSecSuccess || status == errSecItemNotFound
  }
}

private enum ISO639 { static func alpha3(_ code: String) -> String { ["en":"eng", "zh":"zho", "es":"spa", "fr":"fra", "de":"deu", "ja":"jpn", "ko":"kor", "pt":"por", "ru":"rus", "ar":"ara", "hi":"hin", "id":"ind", "vi":"vie", "th":"tha", "it":"ita", "nl":"nld", "tr":"tur", "pl":"pol" ][code.lowercased()] ?? "" } }
private enum ISO3166 { static func alpha3(_ code: String) -> String { ["US":"USA", "CN":"CHN", "GB":"GBR", "JP":"JPN", "KR":"KOR", "CA":"CAN", "AU":"AUS", "DE":"DEU", "FR":"FRA", "IT":"ITA", "ES":"ESP", "BR":"BRA", "IN":"IND", "ID":"IDN", "SG":"SGP", "MY":"MYS", "TH":"THA", "VN":"VNM", "PH":"PHL", "RU":"RUS", "MX":"MEX", "AE":"ARE", "HK":"HKG", "TW":"TWN", "MO":"MAC" ][code.uppercased()] ?? "" } }
