import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let mapsChannelName = "in.jivo.quick/maps"

  /// True once a Google Maps key was handed to the SDK (DL-80).
  private var mapsKeyProvided = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The key comes from the build setting MAPS_API_KEY_IOS through the
    // Info.plist entry GMSApiKey (ios/Flutter/*.xcconfig, gitignored
    // MapsKey.xcconfig, README "Google Maps key"). It is never in the repo.
    // It must reach the SDK before any map is created, so this runs before
    // super, which leads to the scene's FlutterViewController and its engine.
    if let key = AppDelegate.mapsApiKey() {
      GMSServices.provideAPIKey(key)
      mapsKeyProvided = true
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The engine is created implicitly by the storyboard's
    // FlutterViewController in the scene (UIScene setup), so its messenger is
    // only available here, not in didFinishLaunching. Dart asks `prepare`
    // before it shows a Google map; without a key the app keeps its no-map
    // fallback (mirrors MainActivity.kt).
    let channel = FlutterMethodChannel(
      name: AppDelegate.mapsChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    let provided = mapsKeyProvided
    channel.setMethodCallHandler { call, result in
      if call.method == "prepare" {
        result(provided)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// The GMSApiKey from Info.plist, or nil when the build had no key (empty,
  /// or an unexpanded `$(...)` if the build setting was missing entirely).
  private static func mapsApiKey() -> String? {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String else {
      return nil
    }
    let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if key.isEmpty || key.hasPrefix("$(") {
      return nil
    }
    return key
  }
}
