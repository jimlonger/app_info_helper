import AdSupport
import AppTrackingTransparency
import Flutter
import UIKit
import MachO

public final class AppInfoHelperPlugin: NSObject, FlutterPlugin {
  private let storage = UserDefaults.standard
  private let localUuidKey = "app_device_info.local_uuid"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "app_info_helper", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(AppInfoHelperPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getAll": result(all())
    case "refreshAdvertisingId": result(identifiers())
    case "refreshDeviceId": result(identifiers())
    case "resetLocalUuid": storage.set(UUID().uuidString, forKey: localUuidKey); result(identifiers())
    case "requestIdfaAuthorization": requestIdfa(result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func all() -> [String: Any] {
    var values = common()
    values.merge(app()) { _, new in new }
    values.merge(locale()) { _, new in new }
    values.merge(identifiers()) { _, new in new }
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
      "availableRamSize": availableRamMb(),
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

  private func identifiers() -> [String: Any] {
    let local = storage.string(forKey: localUuidKey) ?? UUID().uuidString
    storage.set(local, forKey: localUuidKey)
    let idfv = UIDevice.current.identifierForVendor?.uuidString ?? ""
    let idfa = currentIdfa()
    return ["idfa": idfa, "andi": "", "aifa": "", "gaid": "", "aaid": "", "oaid": "", "asid": "", "idfv": idfv, "localUuid": local, "advertisingId": idfa, "deviceId": idfv.isEmpty ? local : idfv]
  }

  private func requestIdfa(_ result: @escaping FlutterResult) {
    guard #available(iOS 14, *) else { result(failure("unavailable")); return }
    ATTrackingManager.requestTrackingAuthorization { status in
      let idfa = status == .authorized ? self.currentIdfa() : ""
      if !idfa.isEmpty { var data = self.identifiers(); data["isSuccess"] = true; data["failure"] = "none"; result(data); return }
      result(self.failure(status == .denied ? "denied" : status == .restricted ? "restricted" : "invalidIdfa"))
    }
  }

  private func currentIdfa() -> String {
    guard #available(iOS 14, *), ATTrackingManager.trackingAuthorizationStatus == .authorized else { return "" }
    let value = ASIdentifierManager.shared().advertisingIdentifier.uuidString
    return value == "00000000-0000-0000-0000-000000000000" ? "" : value
  }
  private func failure(_ code: String) -> [String: Any] { var data = identifiers(); data["isSuccess"] = false; data["failure"] = code; return data }
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
  private func availableRamMb() -> Int64 { Int64(ProcessInfo.processInfo.physicalMemory / 1_048_576) }
}

private enum ISO639 { static func alpha3(_ code: String) -> String { ["en":"eng", "zh":"zho", "es":"spa", "fr":"fra", "de":"deu", "ja":"jpn", "ko":"kor", "pt":"por", "ru":"rus", "ar":"ara", "hi":"hin", "id":"ind", "vi":"vie", "th":"tha", "it":"ita", "nl":"nld", "tr":"tur", "pl":"pol" ][code.lowercased()] ?? "eng" } }
private enum ISO3166 { static func alpha3(_ code: String) -> String { ["US":"USA", "CN":"CHN", "GB":"GBR", "JP":"JPN", "KR":"KOR", "CA":"CAN", "AU":"AUS", "DE":"DEU", "FR":"FRA", "IT":"ITA", "ES":"ESP", "BR":"BRA", "IN":"IND", "ID":"IDN", "SG":"SGP", "MY":"MYS", "TH":"THA", "VN":"VNM", "PH":"PHL", "RU":"RUS", "MX":"MEX", "AE":"ARE", "HK":"HKG", "TW":"TWN", "MO":"MAC" ][code.uppercased()] ?? "USA" } }
