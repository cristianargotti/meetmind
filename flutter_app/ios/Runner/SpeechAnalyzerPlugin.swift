import Flutter
import UIKit

/// Native plugin bridging Apple's SpeechAnalyzer API (iOS 26+) to Flutter.
///
/// Currently a **stub** — always reports "not available" so the Dart side
/// falls back to the `speech_to_text` plugin automatically.
///
/// TODO: Implement full SpeechAnalyzer/SpeechTranscriber integration once
/// we can verify the exact Xcode 26 API locally.
class SpeechAnalyzerPlugin: NSObject {
    static let methodChannelName = "com.aurameet/speech_analyzer"
    static let eventChannelName = "com.aurameet/speech_analyzer_events"

    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?

    init(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: SpeechAnalyzerPlugin.methodChannelName,
            binaryMessenger: messenger
        )
        eventChannel = FlutterEventChannel(
            name: SpeechAnalyzerPlugin.eventChannelName,
            binaryMessenger: messenger
        )
        super.init()

        methodChannel.setMethodCallHandler(handle)
        eventChannel.setStreamHandler(self)
    }

    // MARK: - MethodChannel Handler

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            // Stub: always return false so Dart uses speech_to_text fallback
            result(false)

        case "initialize":
            result(FlutterError(
                code: "UNSUPPORTED",
                message: "SpeechAnalyzer not yet implemented — use speech_to_text fallback",
                details: nil
            ))

        case "start":
            result(FlutterError(
                code: "UNSUPPORTED",
                message: "SpeechAnalyzer not yet implemented — use speech_to_text fallback",
                details: nil
            ))

        case "stop":
            result(true)

        case "setLanguage":
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func dispose() {
        methodChannel.setMethodCallHandler(nil)
        eventChannel.setStreamHandler(nil)
    }
}

// MARK: - FlutterStreamHandler

extension SpeechAnalyzerPlugin: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
