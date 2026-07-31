package com.hearbaby.x_app_utils

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.google.android.gms.appset.AppSet
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.ads.identifier.AdvertisingIdClient
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.util.Locale
import java.security.SecureRandom
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class XAppUtilsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var context: Context
  private lateinit var channel: MethodChannel
  private val executor = Executors.newSingleThreadExecutor()
  private val secureLocalIds by lazy { SecureLocalIdStorage(context) }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "x_app_utils")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    executor.shutdown()
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    executor.execute {
      try {
        val options = localIdOptions(call)
        val values = when (call.method) {
          "getAll" -> all(options)
          "refreshAdvertisingId" -> identifiers(options, loadAdvertisingId = true)
          "refreshDeviceId" -> identifiers(options, loadAppSetId = true)
          "readLocalId" -> secureLocalIds.read(slot(call), options).toMap()
          "writeLocalId" -> secureLocalIds.write(slot(call), value(call), options).toMap()
          "deleteLocalId" -> mapOf("success" to secureLocalIds.delete(slot(call), options))
          "containsLocalId" -> mapOf("containsKey" to secureLocalIds.contains(slot(call), options), "localIdsPersisted" to true)
          "resetLocalId" -> secureLocalIds.reset(slot(call), options).toMap()
          "readAllLocalIds" -> secureLocalIds.readAll(options).toMap()
          "deleteAllLocalIds" -> mapOf("success" to secureLocalIds.deleteAll(options))
          "resetAllLocalIds" -> secureLocalIds.resetAll(options).toMap()
          "requestIdfaAuthorization" -> failure(options, "unavailable")
          else -> null
        }
        if (values == null) result.notImplemented() else result.success(values)
      } catch (e: Exception) { result.success(emptyResult()) }
    }
  }

  private fun all(options: LocalIdOptions): Map<String, Any> = HashMap<String, Any>().apply {
    putAll(common()); putAll(android()); putAll(app()); putAll(locale()); putAll(identifiers(options))
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

  private fun identifiers(
    options: LocalIdOptions,
    loadAdvertisingId: Boolean = false,
    loadAppSetId: Boolean = false,
  ): Map<String, Any> {
    val localIds = secureLocalIds.readAll(options)
    val primaryLocalId = localIds.primary
    val secondaryLocalId = localIds.secondary
    val andi = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID).orEmpty()
    val values = mutableMapOf<String, Any>(
      "idfa" to "", "andi" to andi, "oaid" to "", "idfv" to "",
      "primaryLocalId" to primaryLocalId, "secondaryLocalId" to secondaryLocalId,
      "localIdsPersisted" to localIds.persisted,
      "deviceId" to listOf(andi, primaryLocalId).firstOrNull { it.isNotEmpty() }.orEmpty(),
    )
    if (loadAdvertisingId) {
      val gaid = advertisingId()
      values.putAll(mapOf("aifa" to gaid, "gaid" to gaid, "aaid" to gaid, "advertisingId" to gaid))
    }
    if (loadAppSetId) {
      val asid = appSetId()
      values["asid"] = asid
      values["deviceId"] = listOf(andi, asid, primaryLocalId).firstOrNull { it.isNotEmpty() }.orEmpty()
    }
    return values
  }

  private fun advertisingId(): String = runCatching {
    AdvertisingIdClient.getAdvertisingIdInfo(context).let {
      if (it.isLimitAdTrackingEnabled) "" else it.id.orEmpty()
    }
  }.getOrDefault("")

  private fun appSetId(): String = runCatching {
    Tasks.await(AppSet.getClient(context).appSetIdInfo, 2, TimeUnit.SECONDS).id.orEmpty()
  }.getOrDefault("")

  private fun localIdOptions(call: MethodCall): LocalIdOptions {
    val args = call.arguments as? Map<*, *> ?: return LocalIdOptions()
    val options = args["localIdStorageOptions"] as? Map<*, *> ?: return LocalIdOptions()
    return LocalIdOptions(
      fallbackNamespace = options["fallbackNamespace"] as? String,
      primaryKey = options["primaryKey"] as? String,
      secondaryKey = options["secondaryKey"] as? String,
    )
  }
  private fun slot(call: MethodCall) = (call.argument<String>("slot") ?: "primary").let { if (it == "secondary") LocalIdSlot.SECONDARY else LocalIdSlot.PRIMARY }
  private fun value(call: MethodCall) = call.argument<String>("value") ?: throw IllegalArgumentException("Local ID value is required.")
  private fun disk(total: Boolean): Long { val s = StatFs(Environment.getDataDirectory().path); return if (total) s.totalBytes else s.availableBytes }
  private fun ram(total: Boolean): Long { val i = ActivityManager.MemoryInfo(); (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(i); return (if (total) i.totalMem else i.availMem) / 1048576 }
  private fun features() = context.packageManager.systemAvailableFeatures.mapNotNull { it.name }
  private fun isEmulator() = Build.FINGERPRINT.startsWith("generic") || Build.MODEL.contains("Emulator", true) || Build.HARDWARE.contains("goldfish", true)
  private fun signature(bytes: ByteArray?): String = bytes?.let { MessageDigest.getInstance("SHA-256").digest(it).joinToString("") { b -> "%02x".format(b) } }.orEmpty()
  private fun failure(options: LocalIdOptions, value: String) = identifiers(options).toMutableMap().apply { put("isSuccess", false); put("failure", value) }
  private fun emptyResult() = mapOf(
    "isSuccess" to false, "idfa" to "", "failure" to "systemError",
    "primaryLocalId" to UUID.randomUUID().toString(),
    "secondaryLocalId" to UUID.randomUUID().toString(),
    "localIdsPersisted" to false,
  )
}

private enum class LocalIdSlot { PRIMARY, SECONDARY }

private data class LocalIdOptions(
  val fallbackNamespace: String? = null,
  val primaryKey: String? = null,
  val secondaryKey: String? = null,
)

private data class LocalIdResult(
  val primary: String,
  val secondary: String,
  val persisted: Boolean,
) {
  fun toMap() = mapOf<String, Any>("success" to persisted, "primaryLocalId" to primary, "secondaryLocalId" to secondary, "localIdsPersisted" to persisted)
}

private class SecureLocalIdStorage(private val context: Context) {
  private val dataPrefs = context.getSharedPreferences("x_app_utils_secure_local_ids", Context.MODE_PRIVATE)
  private val configPrefs = context.getSharedPreferences("x_app_utils_secure_local_ids_config", Context.MODE_PRIVATE)
  private val keyAlias = "x_app_utils_secure_local_ids_rsa"
  private val aesKeyName = "x_app_utils_secure_local_ids_aes_key"
  private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

  fun read(slot: LocalIdSlot, options: LocalIdOptions): LocalIdResult {
    val all = readAll(options)
    return when (slot) {
      LocalIdSlot.PRIMARY -> LocalIdResult(all.primary, all.secondary, all.persisted)
      LocalIdSlot.SECONDARY -> LocalIdResult(all.primary, all.secondary, all.persisted)
    }
  }

  fun readAll(options: LocalIdOptions): LocalIdResult {
    val primary = getOrCreate(LocalIdSlot.PRIMARY, options)
    val secondary = getOrCreate(LocalIdSlot.SECONDARY, options)
    return LocalIdResult(primary.value, secondary.value, primary.persisted && secondary.persisted)
  }

  fun write(slot: LocalIdSlot, value: String, options: LocalIdOptions): LocalIdResult {
    val persisted = writeKeys(keys(slot, options), value)
    val all = readAll(options)
    return when (slot) {
      LocalIdSlot.PRIMARY -> LocalIdResult(value, all.secondary, persisted && all.persisted)
      LocalIdSlot.SECONDARY -> LocalIdResult(all.primary, value, persisted && all.persisted)
    }
  }

  fun reset(slot: LocalIdSlot, options: LocalIdOptions): LocalIdResult {
    if (!delete(slot, options)) {
      val all = readAll(options)
      return LocalIdResult(all.primary, all.secondary, false)
    }
    return write(slot, UUID.randomUUID().toString(), options)
  }

  fun resetAll(options: LocalIdOptions): LocalIdResult {
    if (!deleteAll(options)) {
      val all = readAll(options)
      return LocalIdResult(all.primary, all.secondary, false)
    }
    val primaryValue = UUID.randomUUID().toString()
    val secondaryValue = UUID.randomUUID().toString()
    val primarySaved = writeKeys(keys(LocalIdSlot.PRIMARY, options), primaryValue)
    val secondarySaved = writeKeys(keys(LocalIdSlot.SECONDARY, options), secondaryValue)
    return LocalIdResult(primaryValue, secondaryValue, primarySaved && secondarySaved)
  }

  fun contains(slot: LocalIdSlot, options: LocalIdOptions) = keys(slot, options).any { dataPrefs.contains(it) }
  fun delete(slot: LocalIdSlot, options: LocalIdOptions): Boolean =
    dataPrefs.edit().also { editor -> keys(slot, options).forEach { editor.remove(it) } }.commit()
  fun deleteAll(options: LocalIdOptions): Boolean =
    delete(LocalIdSlot.PRIMARY, options) && delete(LocalIdSlot.SECONDARY, options)

  private data class ValueResult(val value: String, val persisted: Boolean)

  private fun getOrCreate(slot: LocalIdSlot, options: LocalIdOptions): ValueResult {
    val existing = readPlain(slot, options)
    val value = existing ?: UUID.randomUUID().toString()
    val persisted = writeKeys(keys(slot, options), value)
    return ValueResult(value, persisted)
  }

  private fun readPlain(slot: LocalIdSlot, options: LocalIdOptions): String? {
    for (key in keys(slot, options)) {
      val raw = dataPrefs.getString(key, null) ?: continue
      val value = runCatching { decrypt(raw) }.getOrNull()
      if (!value.isNullOrEmpty()) return value
    }
    return null
  }

  private fun writeKeys(keys: List<String>, value: String): Boolean = runCatching {
    val encrypted = encrypt(value)
    val editor = dataPrefs.edit()
    keys.forEach { editor.putString(it, encrypted) }
    editor.commit()
  }.getOrDefault(false)

  private fun keys(slot: LocalIdSlot, options: LocalIdOptions): List<String> {
    val explicit = if (slot == LocalIdSlot.PRIMARY) options.primaryKey else options.secondaryKey
    if (!explicit.isNullOrEmpty()) return listOf(explicit)
    val suffix = if (slot == LocalIdSlot.PRIMARY) "primaryLocalId" else "secondaryLocalId"
    return listOfNotNull(context.packageName.takeIf { it.isNotEmpty() }, options.fallbackNamespace?.takeIf { it.isNotEmpty() }, "x_app_utils")
      .distinct()
      .map { "$it.$suffix" }
  }

  private fun encrypt(value: String): String {
    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
    val iv = ByteArray(12).also { SecureRandom().nextBytes(it) }
    cipher.init(Cipher.ENCRYPT_MODE, getAesKey(), GCMParameterSpec(128, iv))
    val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
    return Base64.encodeToString(iv + encrypted, Base64.NO_WRAP)
  }

  private fun decrypt(value: String): String {
    val bytes = Base64.decode(value, Base64.NO_WRAP)
    val iv = bytes.copyOfRange(0, 12)
    val encrypted = bytes.copyOfRange(12, bytes.size)
    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
    cipher.init(Cipher.DECRYPT_MODE, getAesKey(), GCMParameterSpec(128, iv))
    return String(cipher.doFinal(encrypted), Charsets.UTF_8)
  }

  private fun getAesKey(): SecretKey {
    val wrapped = configPrefs.getString(aesKeyName, null)
    if (wrapped != null) {
      val cipher = Cipher.getInstance("RSA/ECB/OAEPWithSHA-256AndMGF1Padding")
      cipher.init(Cipher.UNWRAP_MODE, getOrCreateKeyPair().private)
      return cipher.unwrap(Base64.decode(wrapped, Base64.NO_WRAP), "AES", Cipher.SECRET_KEY) as SecretKey
    }
    val key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
    val cipher = Cipher.getInstance("RSA/ECB/OAEPWithSHA-256AndMGF1Padding")
    cipher.init(Cipher.WRAP_MODE, getOrCreateKeyPair().public)
    configPrefs.edit().putString(aesKeyName, Base64.encodeToString(cipher.wrap(key), Base64.NO_WRAP)).commit()
    return key
  }

  private fun getOrCreateKeyPair(): java.security.KeyPair {
    (keyStore.getEntry(keyAlias, null) as? KeyStore.PrivateKeyEntry)?.let { return java.security.KeyPair(it.certificate.publicKey, it.privateKey) }
    val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore")
    generator.initialize(KeyGenParameterSpec.Builder(keyAlias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
      .setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA512)
      .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
      .build())
    return generator.generateKeyPair()
  }
}
