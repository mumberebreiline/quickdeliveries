import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GMSServices.provideAPIKey("AIzaSyCruXFbmeJFxXr2eKdnkVmkr51Wop74K70")
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
