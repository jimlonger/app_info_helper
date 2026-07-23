package com.hearbaby.app_info_helper

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import com.google.android.gms.appset.AppSet
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.ads.identifier.AdvertisingIdClient
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.Executors

class AppInfoHelperPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var context: Context
  private lateinit var channel: MethodChannel
  private val executor = Executors.newSingleThreadExecutor()

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "app_info_helper")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    executor.shutdown()
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    executor.execute {
      try {
        val values = when (call.method) {
          "getAll" -> all()
          "refreshAdvertisingId" -> identifiers(refreshAdvertising = true)
          "refreshDeviceId" -> identifiers(refreshDevice = true)
          "resetLocalUuid" -> { prefs().edit().putString("localUuid", UUID.randomUUID().toString()).apply(); identifiers(refreshDevice = true) }
          "requestIdfaAuthorization" -> failure("unavailable")
          else -> null
        }
        if (values == null) result.notImplemented() else result.success(values)
      } catch (t: Throwable) { result.success(emptyResult()) }
    }
  }

  private fun all(): Map<String, Any> = HashMap<String, Any>().apply {
    putAll(common()); putAll(android()); putAll(app()); putAll(locale()); putAll(identifiers(true, true))
  }

  private fun common() = mapOf<String, Any>(
    "deviceModel" to Build.MODEL.orEmpty(), "platform" to Build.MANUFACTURER.orEmpty(),
    "osVersion" to Build.VERSION.SDK_INT.toString(), "systemName" to "Android",
    "deviceName" to (if (Build.VERSION.SDK_INT >= 25) Settings.Global.getString(context.contentResolver, Settings.Global.DEVICE_NAME).orEmpty() else ""),
    "isPhysicalDevice" to !isEmulator(), "freeDiskSize" to disk(false), "totalDiskSize" to disk(true),
    "physicalRamSize" to ram(true), "availableRamSize" to ram(false)
  )

  private fun android(): Map<String, Any> = mapOf(
    "androidBoard" to Build.BOARD.orEmpty(), "androidBootloader" to Build.BOOTLOADER.orEmpty(), "androidBrand" to Build.BRAND.orEmpty(),
    "androidDevice" to Build.DEVICE.orEmpty(), "androidDisplay" to Build.DISPLAY.orEmpty(), "androidFingerprint" to Build.FINGERPRINT.orEmpty(),
    "androidHardware" to Build.HARDWARE.orEmpty(), "androidHost" to Build.HOST.orEmpty(), "androidId" to Build.ID.orEmpty(),
    "androidProduct" to Build.PRODUCT.orEmpty(), "androidSupported32BitAbis" to Build.SUPPORTED_32_BIT_ABIS.toList(),
    "androidSupported64BitAbis" to Build.SUPPORTED_64_BIT_ABIS.toList(), "androidSupportedAbis" to Build.SUPPORTED_ABIS.toList(),
    "androidTags" to Build.TAGS.orEmpty(), "androidType" to Build.TYPE.orEmpty(), "androidSystemFeatures" to features(),
    "androidIsLowRamDevice" to (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).isLowRamDevice,
    "androidBaseOs" to if (Build.VERSION.SDK_INT >= 23) Build.VERSION.BASE_OS.orEmpty() else "",
    "androidSdkInt" to Build.VERSION.SDK_INT, "androidRelease" to Build.VERSION.RELEASE.orEmpty(),
    "androidCodename" to Build.VERSION.CODENAME.orEmpty(), "androidIncremental" to Build.VERSION.INCREMENTAL.orEmpty(),
    "androidPreviewSdkInt" to if (Build.VERSION.SDK_INT >= 23) Build.VERSION.PREVIEW_SDK_INT else 0,
    "androidSecurityPatch" to if (Build.VERSION.SDK_INT >= 23) Build.VERSION.SECURITY_PATCH.orEmpty() else ""
  )

  private fun app(): Map<String, Any> {
    val p = context.packageManager; val pi = p.getPackageInfo(context.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
    val versionCode = if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else pi.versionCode.toLong()
    val signatures = if (Build.VERSION.SDK_INT >= 28) pi.signingInfo?.apkContentsSigners else @Suppress("DEPRECATION") pi.signatures
    return mapOf("appName" to context.applicationInfo.loadLabel(p).toString(), "packageName" to context.packageName,
      "version" to pi.versionName.orEmpty(), "buildNumber" to versionCode.toString(), "buildSignature" to signature(signatures?.firstOrNull()?.toByteArray()),
      "installerStore" to (if (Build.VERSION.SDK_INT >= 30) p.getInstallSourceInfo(context.packageName).installingPackageName.orEmpty() else @Suppress("DEPRECATION") p.getInstallerPackageName(context.packageName).orEmpty()),
      "installTime" to pi.firstInstallTime, "updateTime" to pi.lastUpdateTime)
  }

  private fun locale(): Map<String, Any> {
    val l = if (Build.VERSION.SDK_INT >= 24) context.resources.configuration.locales[0] else @Suppress("DEPRECATION") context.resources.configuration.locale
    val tz = TimeZone.getDefault(); val now = System.currentTimeMillis()
    return mapOf("languageCode" to l.language.ifEmpty { "en" }, "languageCode3" to runCatching { l.getISO3Language() }.getOrDefault("eng"),
      "countryCode" to l.country.ifEmpty { "US" }, "countryCode3" to runCatching { l.getISO3Country() }.getOrDefault("USA"),
      "locale" to l.toLanguageTag().ifEmpty { "en-US" }, "timeZone" to tz.id.orEmpty(), "utcOffsetSeconds" to tz.getOffset(now) / 1000)
  }

  private fun identifiers(refreshAdvertising: Boolean = false, refreshDevice: Boolean = false): Map<String, Any> {
    val local = prefs().getString("localUuid", null) ?: UUID.randomUUID().toString().also { prefs().edit().putString("localUuid", it).apply() }
    val andi = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID).orEmpty()
    val gaid = if (refreshAdvertising || true) runCatching { AdvertisingIdClient.getAdvertisingIdInfo(context).let { if (it.isLimitAdTrackingEnabled) "" else it.id.orEmpty() } }.getOrDefault("") else ""
    val asid = if (refreshDevice || true) runCatching { Tasks.await(AppSet.getClient(context).appSetIdInfo).id.orEmpty() }.getOrDefault("") else ""
    val oaid = "" // Optional MSA SDK may be integrated by a host flavor; unsupported devices return ''.
    val aifa = gaid
    return mapOf("idfa" to "", "andi" to andi, "aifa" to aifa, "gaid" to gaid, "aaid" to gaid, "oaid" to oaid, "asid" to asid, "idfv" to "", "localUuid" to local,
      "advertisingId" to listOf(aifa, gaid, oaid).firstOrNull { it.isNotEmpty() }.orEmpty(), "deviceId" to listOf(andi, asid, local).firstOrNull { it.isNotEmpty() }.orEmpty())
  }

  private fun prefs() = context.getSharedPreferences("app_device_info", Context.MODE_PRIVATE)
  private fun disk(total: Boolean): Long { val s = StatFs(Environment.getDataDirectory().path); return if (total) s.totalBytes else s.availableBytes }
  private fun ram(total: Boolean): Long { val i = ActivityManager.MemoryInfo(); (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(i); return (if (total) i.totalMem else i.availMem) / 1048576 }
  private fun features() = context.packageManager.systemAvailableFeatures.mapNotNull { it.name }
  private fun isEmulator() = Build.FINGERPRINT.startsWith("generic") || Build.MODEL.contains("Emulator", true) || Build.HARDWARE.contains("goldfish", true)
  private fun signature(bytes: ByteArray?): String = bytes?.let { MessageDigest.getInstance("SHA-256").digest(it).joinToString("") { b -> "%02x".format(b) } }.orEmpty()
  private fun failure(value: String) = mapOf("isSuccess" to false, "idfa" to "", "failure" to value)
  private fun emptyResult() = failure("systemError")
}
