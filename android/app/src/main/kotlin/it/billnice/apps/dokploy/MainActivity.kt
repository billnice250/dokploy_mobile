package it.billnice.apps.dokploy

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.security.KeyStore
import java.security.MessageDigest

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dploygo/certificate_inspector",
        ).setMethodCallHandler { call, result ->
            if (call.method != "pkcs12Sha1Thumbprint") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            val password = call.argument<String>("password")
            if (bytes == null || password == null) {
                result.error("INVALID_ARGUMENT", "PKCS#12 bytes and password are required.", null)
                return@setMethodCallHandler
            }
            try {
                val keyStore = KeyStore.getInstance("PKCS12")
                keyStore.load(ByteArrayInputStream(bytes), password.toCharArray())
                val aliases = keyStore.aliases()
                if (!aliases.hasMoreElements()) {
                    result.error("CERTIFICATE_MISSING", "No X.509 certificate was found in the identity.", null)
                    return@setMethodCallHandler
                }
                val certificate = keyStore.getCertificate(aliases.nextElement())
                val digest = MessageDigest.getInstance("SHA-1").digest(certificate.encoded)
                result.success(digest.joinToString(":") { "%02X".format(it) })
            } catch (error: Exception) {
                result.error("PKCS12_IMPORT_FAILED", "The client certificate or password is invalid.", error.message)
            }
        }
    }
}
