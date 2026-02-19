import Flutter
import UIKit
import AVFoundation

#if compiler(>=6.2)
import Speech
#endif

/// Native plugin bridging Apple's SpeechAnalyzer API (iOS 26+) to Flutter.
///
/// Uses MethodChannel for commands (start/stop/setLanguage) and
/// EventChannel for streaming transcription results back to Dart.
///
/// **Compile-time behavior:**
/// - Xcode 26+ (Swift 6.2+): Full SpeechAnalyzer implementation
/// - Older Xcode: Stub that reports "not available", Dart side
///   falls back to the legacy `speech_to_text` plugin automatically.
class SpeechAnalyzerPlugin: NSObject {
    static let methodChannelName = "com.aurameet/speech_analyzer"
    static let eventChannelName = "com.aurameet/speech_analyzer_events"

    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?

    // State
    private var isListening = false
    private var currentLocale = "es-CO"

    // Type-erased to compile on older SDKs
    private var analyzerTask: Any?
    private var audioEngine: AVAudioEngine?

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
            result(isAnalyzerAvailable())

        case "initialize":
            let args = call.arguments as? [String: Any]
            let locale = args?["locale"] as? String ?? "es-CO"
            currentLocale = locale
            initializeEngine(locale: locale, result: result)

        case "start":
            let args = call.arguments as? [String: Any]
            let locale = args?["locale"] as? String ?? currentLocale
            currentLocale = locale
            startListening(locale: locale, result: result)

        case "stop":
            stopListening(result: result)

        case "setLanguage":
            let args = call.arguments as? [String: Any]
            if let locale = args?["locale"] as? String {
                currentLocale = locale
                if isListening {
                    stopListeningInternal()
                    startListening(locale: locale, result: result)
                } else {
                    result(true)
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "locale required", details: nil))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Availability Check

    private func isAnalyzerAvailable() -> Bool {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return SpeechTranscriber.isAvailable
        }
        #endif
        return false
    }

    // MARK: - Initialize

    private func initializeEngine(locale: String, result: @escaping FlutterResult) {
        guard isAnalyzerAvailable() else {
            result(FlutterError(code: "UNSUPPORTED", message: "SpeechAnalyzer requires iOS 26+", details: nil))
            return
        }

        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            if granted {
                                result(true)
                            } else {
                                result(FlutterError(code: "MIC_DENIED", message: "Microphone permission denied", details: nil))
                            }
                        }
                    }
                default:
                    result(FlutterError(code: "SPEECH_DENIED", message: "Speech recognition denied (status: \(status.rawValue))", details: nil))
                }
            }
        }
    }

    // MARK: - Start Listening

    private func startListening(locale: String, result: @escaping FlutterResult) {
        guard !isListening else {
            result(true)
            return
        }

        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            startWithSpeechAnalyzer(locale: locale, result: result)
            return
        }
        #endif

        result(FlutterError(code: "UNSUPPORTED", message: "SpeechAnalyzer requires iOS 26.0+", details: nil))
    }

    // MARK: - SpeechAnalyzer Implementation (iOS 26+ SDK only)

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private func startWithSpeechAnalyzer(locale: String, result: @escaping FlutterResult) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            let speechLocale = Locale(identifier: locale)
            let transcriber = SpeechTranscriber(locale: speechLocale, preset: .progressiveTranscription)
            let analyzer = SpeechAnalyzer(modules: [transcriber])

            // Install audio tap to feed buffers to analyzer
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
                buffer, when in
                Task {
                    let input = AnalyzerInput(buffer: buffer)
                    try? await analyzer.start(inputSequence: AsyncStream { cont in
                        cont.yield(input)
                        cont.finish()
                    })
                }
            }

            engine.prepare()
            try engine.start()

            self.audioEngine = engine
            self.isListening = true

            self.sendEvent([
                "type": "status",
                "status": "listening",
                "locale": locale,
            ])

            result(true)

            // Read transcription results
            let task = Task { [weak self] in
                do {
                    for try await transcriptionResult in transcriber.results {
                        guard let self = self, self.isListening else { break }

                        let isFinal = transcriptionResult.isFinal
                        let text = String(transcriptionResult.text.characters)

                        DispatchQueue.main.async {
                            if isFinal {
                                self.sendEvent([
                                    "type": "final",
                                    "text": text,
                                    "confidence": 0.9,
                                    "locale": locale,
                                ])
                            } else {
                                self.sendEvent([
                                    "type": "partial",
                                    "text": text,
                                    "confidence": 0.8,
                                    "locale": locale,
                                ])
                            }
                        }
                    }
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        self?.sendEvent([
                            "type": "error",
                            "message": error.localizedDescription,
                        ])
                    }
                }

                DispatchQueue.main.async { [weak self] in
                    self?.sendEvent([
                        "type": "status",
                        "status": "done",
                        "locale": locale,
                    ])
                }
            }
            self.analyzerTask = task

        } catch {
            result(FlutterError(
                code: "AUDIO_ERROR",
                message: "Failed to start audio engine: \(error.localizedDescription)",
                details: nil
            ))
        }
    }
    #endif

    // MARK: - Stop Listening

    private func stopListening(result: @escaping FlutterResult) {
        stopListeningInternal()
        result(true)
    }

    private func stopListeningInternal() {
        #if compiler(>=6.2)
        if let task = analyzerTask as? Task<Void, Never> {
            task.cancel()
        }
        #endif
        analyzerTask = nil

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        isListening = false

        sendEvent([
            "type": "status",
            "status": "stopped",
            "locale": currentLocale,
        ])
    }

    // MARK: - Event Helpers

    private func sendEvent(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }

    func dispose() {
        stopListeningInternal()
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
