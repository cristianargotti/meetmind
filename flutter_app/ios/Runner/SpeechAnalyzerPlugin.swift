import Flutter
import UIKit
import AVFoundation
import Speech

/// Native plugin bridging Apple's SpeechAnalyzer API (iOS 26+) to Flutter.
///
/// Uses MethodChannel for commands (start/stop/setLanguage) and
/// EventChannel for streaming transcription results back to Dart.
///
/// **Requires iOS 26.0+ deployment target.**
class SpeechAnalyzerPlugin: NSObject {
    static let methodChannelName = "com.aurameet/speech_analyzer"
    static let eventChannelName = "com.aurameet/speech_analyzer_events"

    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?

    // State
    private var isListening = false
    private var currentLocale = "es-CO"

    // Audio
    private var audioEngine: AVAudioEngine?
    private var audioContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var transcriptionTask: Task<Void, Never>?
    private var analyzerTask: Task<Void, Never>?

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
            Task {
                let available = await SpeechTranscriber.isAvailable
                DispatchQueue.main.async { result(available) }
            }

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

        case "getSupportedLocales":
            Task {
                let locales = await SpeechTranscriber.supportedLocales.map { $0.identifier }
                DispatchQueue.main.async { result(locales) }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Locale Resolution

    /// Resolve user locale to a supported SpeechTranscriber locale.
    private func resolveLocale(_ requested: String) async -> Locale {
        let supported = await SpeechTranscriber.supportedLocales
        let requestedLocale = Locale(identifier: requested)

        // 1. Exact match
        if supported.contains(where: { $0.identifier == requested }) {
            debugPrint("[SpeechAnalyzer] Locale exact match: \(requested)")
            return requestedLocale
        }

        // 2. Same language variant (e.g., es-CO -> es-ES or es-MX)
        let lang = requestedLocale.language.languageCode?.identifier ?? "es"
        if let variant = supported.first(where: {
            $0.language.languageCode?.identifier == lang
        }) {
            debugPrint("[SpeechAnalyzer] Locale fallback: \(requested) -> \(variant.identifier)")
            return variant
        }

        // 3. Default to first supported locale
        let fallback = supported.first ?? Locale(identifier: "en-US")
        debugPrint("[SpeechAnalyzer] Locale default fallback: \(requested) -> \(fallback.identifier)")
        return fallback
    }

    // MARK: - Initialize

    private func initializeEngine(locale: String, result: @escaping FlutterResult) {
        Task {
            guard await SpeechTranscriber.isAvailable else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "UNSUPPORTED", message: "SpeechAnalyzer not available", details: nil))
                }
                return
            }

            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        AVAudioSession.sharedInstance().requestRecordPermission { granted in
                            DispatchQueue.main.async {
                                result(granted ? true : FlutterError(code: "MIC_DENIED", message: "Microphone denied", details: nil))
                            }
                        }
                    default:
                        result(FlutterError(code: "SPEECH_DENIED", message: "Speech denied (status: \(status.rawValue))", details: nil))
                    }
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

        Task { [weak self] in
            guard let self = self else { return }

            do {
                // 1. Configure audio session
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                // 2. Setup transcriber with resolved locale
                let speechLocale = await self.resolveLocale(locale)
                let supportedIds = await SpeechTranscriber.supportedLocales.map { $0.identifier }
                debugPrint("[SpeechAnalyzer] Supported: \(supportedIds)")
                debugPrint("[SpeechAnalyzer] Using: \(speechLocale.identifier)")

                let transcriber = SpeechTranscriber(locale: speechLocale, preset: .progressiveTranscription)
                let analyzer = SpeechAnalyzer(modules: [transcriber])

                // 3. Setup audio engine
                let engine = AVAudioEngine()
                let inputNode = engine.inputNode
                let micFormat = inputNode.outputFormat(forBus: 0)

                // 4. Get the BEST audio format for the analyzer
                // This is CRITICAL — the analyzer needs a specific format
                let analyzerFormat: AVAudioFormat
                if let bestFormat = try await SpeechAnalyzer.bestAvailableAudioFormat(
                    compatibleWith: [transcriber],
                    considering: micFormat
                ) {
                    analyzerFormat = bestFormat
                } else {
                    analyzerFormat = micFormat // fallback to mic format
                    debugPrint("[SpeechAnalyzer] WARNING: bestAvailableAudioFormat returned nil, using mic format")
                }
                debugPrint("[SpeechAnalyzer] Mic format: \(micFormat)")
                debugPrint("[SpeechAnalyzer] Analyzer format: \(analyzerFormat)")

                // 5. Create audio converter if formats differ
                let converter: AVAudioConverter?
                if micFormat != analyzerFormat {
                    converter = AVAudioConverter(from: micFormat, to: analyzerFormat)
                    debugPrint("[SpeechAnalyzer] Audio converter created")
                } else {
                    converter = nil
                    debugPrint("[SpeechAnalyzer] No conversion needed")
                }

                // 6. Create continuous AsyncStream for feeding audio
                var continuation: AsyncStream<AnalyzerInput>.Continuation!
                let audioStream = AsyncStream<AnalyzerInput> { cont in
                    continuation = cont
                }
                self.audioContinuation = continuation

                // 7. Install audio tap — convert & yield each buffer
                inputNode.installTap(onBus: 0, bufferSize: 4096, format: micFormat) { [weak self] buffer, when in
                    guard let self = self, self.isListening else { return }

                    if let converter = converter {
                        // Convert to analyzer format
                        let frameCount = AVAudioFrameCount(
                            Double(buffer.frameLength) * analyzerFormat.sampleRate / micFormat.sampleRate
                        )
                        guard let convertedBuffer = AVAudioPCMBuffer(
                            pcmFormat: analyzerFormat,
                            frameCapacity: frameCount
                        ) else { return }

                        var error: NSError?
                        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                            outStatus.pointee = .haveData
                            return buffer
                        }

                        if error == nil {
                            let input = AnalyzerInput(buffer: convertedBuffer)
                            self.audioContinuation?.yield(input)
                        } else {
                            debugPrint("[SpeechAnalyzer] Conversion error: \(error!)")
                        }
                    } else {
                        // No conversion needed
                        let input = AnalyzerInput(buffer: buffer)
                        self.audioContinuation?.yield(input)
                    }
                }

                // 8. Start engine
                engine.prepare()
                try engine.start()

                self.audioEngine = engine
                self.isListening = true

                self.sendEvent([
                    "type": "status",
                    "status": "listening",
                    "locale": locale,
                ])
                DispatchQueue.main.async { result(true) }

                // 9. Start analyzer with continuous audio stream
                self.analyzerTask = Task {
                    do {
                        try await analyzer.start(inputSequence: audioStream)
                    } catch {
                        debugPrint("[SpeechAnalyzer] Analyzer error: \(error)")
                        DispatchQueue.main.async { [weak self] in
                            self?.sendEvent([
                                "type": "error",
                                "message": "Analyzer: \(error.localizedDescription)",
                            ])
                        }
                    }
                }

                // 10. Read transcription results
                self.transcriptionTask = Task { [weak self] in
                    do {
                        for try await transcriptionResult in transcriber.results {
                            guard let self = self, self.isListening else { break }

                            let isFinal = transcriptionResult.isFinal
                            let text = String(transcriptionResult.text.characters)

                            debugPrint("[SpeechAnalyzer] \(isFinal ? "FINAL" : "partial"): \(text)")

                            DispatchQueue.main.async {
                                self.sendEvent([
                                    "type": isFinal ? "final" : "partial",
                                    "text": text,
                                    "confidence": isFinal ? 1.0 : 0.5,
                                    "locale": locale,
                                ])
                            }
                        }
                    } catch {
                        debugPrint("[SpeechAnalyzer] Transcription error: \(error)")
                        DispatchQueue.main.async { [weak self] in
                            self?.sendEvent([
                                "type": "error",
                                "message": "Transcription: \(error.localizedDescription)",
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

            } catch {
                debugPrint("[SpeechAnalyzer] Start error: \(error)")
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "AUDIO_ERROR",
                        message: "Failed: \(error.localizedDescription)",
                        details: nil
                    ))
                }
            }
        }
    }

    // MARK: - Stop Listening

    private func stopListening(result: @escaping FlutterResult) {
        stopListeningInternal()
        result(true)
    }

    private func stopListeningInternal() {
        isListening = false

        audioContinuation?.finish()
        audioContinuation = nil

        analyzerTask?.cancel()
        analyzerTask = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

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
