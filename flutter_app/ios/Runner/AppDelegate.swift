import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var speechAnalyzerPlugin: SpeechAnalyzerPlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Register native SpeechAnalyzer plugin (iOS 26+ continuous STT)
    // Uses FlutterPluginRegistry API to avoid rootViewController deprecation
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SpeechAnalyzerPlugin") {
      speechAnalyzerPlugin = SpeechAnalyzerPlugin(
        messenger: registrar.messenger()
      )
    }
  }
}
