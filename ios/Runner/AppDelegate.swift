import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let storageChannel = FlutterMethodChannel(
      name: "com.arkive/storage",
      binaryMessenger: controller.binaryMessenger
    )
    storageChannel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let arguments = call.arguments as? [String: Any],
        let filePath = arguments["filePath"] as? String
      else {
        result(FlutterError(
          code: "INVALID_ARGUMENT",
          message: "A file path is required.",
          details: nil
        ))
        return
      }

      do {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var fileURL = URL(fileURLWithPath: filePath)
        try fileURL.setResourceValues(resourceValues)
        result(true)
      } catch {
        result(FlutterError(
          code: "BACKUP_EXCLUSION_FAILED",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
