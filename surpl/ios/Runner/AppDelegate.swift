import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The Maps key comes from Info.plist (GMSApiKey = $(GMS_API_KEY) from Flutter/Secrets.xcconfig),
    // so it never lives in source control.
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String, !key.isEmpty, !key.hasPrefix("$(") {
      GMSServices.provideAPIKey(key)
    } else {
      NSLog("Surpl: GMSApiKey missing — Google Maps tiles will not load. Run scripts/ios-setup.sh.")
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
