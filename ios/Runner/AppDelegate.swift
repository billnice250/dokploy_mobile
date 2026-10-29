import Flutter
import CryptoKit
import Security
import UIKit
import UserNotifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "DployGoCertificateInspector"
    ) else { return }
    let channel = FlutterMethodChannel(
      name: "dploygo/certificate_inspector",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "pkcs12Sha1Thumbprint" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let typedData = arguments["bytes"] as? FlutterStandardTypedData,
        let password = arguments["password"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "PKCS#12 bytes and password are required.", details: nil))
        return
      }
      let options = [kSecImportExportPassphrase as String: password]
      var imported: CFArray?
      let status = SecPKCS12Import(typedData.data as CFData, options as CFDictionary, &imported)
      guard
        status == errSecSuccess,
        let items = imported as? [[String: Any]],
        let identity = items.first?[kSecImportItemIdentity as String] as! SecIdentity?
      else {
        result(FlutterError(code: "PKCS12_IMPORT_FAILED", message: "The client certificate or password is invalid.", details: status))
        return
      }
      var certificate: SecCertificate?
      guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
            let certificate else {
        result(FlutterError(code: "CERTIFICATE_MISSING", message: "No X.509 certificate was found in the identity.", details: nil))
        return
      }
      let der = SecCertificateCopyData(certificate) as Data
      let digest = Insecure.SHA1.hash(data: der)
      result(digest.map { String(format: "%02X", $0) }.joined(separator: ":"))
    }
    let widgetChannel = FlutterMethodChannel(
      name: "dploygo/home_widget",
      binaryMessenger: registrar.messenger()
    )
    widgetChannel.setMethodCallHandler { call, result in
      guard call.method == "updateSummary",
            let values = call.arguments as? [String: Any],
            let defaults = UserDefaults(suiteName: "group.it.billnice.apps.dokploy") else {
        result(FlutterMethodNotImplemented)
        return
      }
      for key in ["instanceName", "running", "stopped", "failed", "updatedAt"] {
        defaults.set(values[key], forKey: key)
      }
      if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadAllTimelines()
      }
      result(true)
    }
  }
}
