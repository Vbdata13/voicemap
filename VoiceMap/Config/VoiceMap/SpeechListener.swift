import Foundation
import AVFoundation
import Speech

final class SpeechListener: NSObject, ObservableObject {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // silence detection
    private var endWorkItem: DispatchWorkItem?
    private let endDelay: TimeInterval = 0.8  // stop ~0.8s after last speech

    // latest text so UI can use it if user taps Stop before final result
    private(set) var latestText: String = ""

    // MARK: - Permissions
    
    func hasPermissions() -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized && 
               AVAudioSession.sharedInstance().recordPermission == .granted
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        // Check current permissions first to avoid unnecessary delays
        let currentSpeechAuth = SFSpeechRecognizer.authorizationStatus()
        let currentMicAuth = AVAudioSession.sharedInstance().recordPermission
        
        // If already authorized, return immediately
        if currentSpeechAuth == .authorized && currentMicAuth == .granted {
            DispatchQueue.main.async {
                completion(true)
            }
            return
        }
        
        // Only request if needed
        if currentSpeechAuth != .authorized {
            SFSpeechRecognizer.requestAuthorization { auth in
                if currentMicAuth == .granted {
                    DispatchQueue.main.async {
                        completion(auth == .authorized)
                    }
                } else {
                    AVAudioSession.sharedInstance().requestRecordPermission { micOK in
                        DispatchQueue.main.async {
                            completion(auth == .authorized && micOK)
                        }
                    }
                }
            }
        } else {
            // Speech already authorized, just check mic
            AVAudioSession.sharedInstance().requestRecordPermission { micOK in
                DispatchQueue.main.async {
                    completion(micOK)
                }
            }
        }
    }

    // MARK: - Session helpers

    /// Keep session simple and stable. We also call this in `startListening()`
    func prewarmAudioSession() {
        let s = AVAudioSession.sharedInstance()
        // Voice chat is low-latency, routes to speaker, and supports AirPods
        try? s.setCategory(.playAndRecord,
                           mode: .voiceChat,
                           options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .duckOthers])
        try? s.setActive(true, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Start / Stop

    /// Begin recognition; `onText` is called with (partialText, isFinal)
    func startListening(onText: @escaping (String, Bool) -> Void) throws {
        guard recognizer?.isAvailable == true else { throw NSError(domain: "Speech", code: -1) }

        // Clean any previous run, but keep session active for speed.
        stopListening(cleanSession: false)

        // Make sure the session is configured/active right now
        prewarmAudioSession()

        // fresh request every time
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true {
            req.requiresOnDeviceRecognition = true // faster if available
        }
        req.taskHint = .dictation
        request = req
        latestText = ""

        // Feed mic into the request
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        // Use nil format to match the hardware route automatically.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            self.request?.append(buffer)
        }

        if !audioEngine.isRunning {
            audioEngine.prepare()
            try audioEngine.start()
        }

        // Recognition task
        task = recognizer?.recognitionTask(with: req) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    self.latestText = text
                    onText(text, false) // partial

                    // Silence-based auto-finalization:
                    self.endWorkItem?.cancel()
                    let work = DispatchWorkItem { [weak self] in
                        guard let self else { return }
                        DispatchQueue.main.async {
                            onText(text, true)
                            self.stopListening(cleanSession: false)
                        }
                    }
                    self.endWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.endDelay, execute: work)

                    if result.isFinal {
                        self.endWorkItem?.cancel()
                        onText(text, true)
                        self.stopListening(cleanSession: false)
                    }
                }

                if error != nil {
                    self.endWorkItem?.cancel()
                    self.stopListening(cleanSession: false)
                }
            }
        }
    }

    /// Stop streaming; optionally tear down the session (for fully fresh restarts)
    func stopListening(cleanSession: Bool = true) {
        endWorkItem?.cancel(); endWorkItem = nil
        task?.cancel(); task = nil
        request?.endAudio(); request = nil

        if audioEngine.isRunning { audioEngine.stop() }
        // Defensive: remove tap if present
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        if cleanSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// Stop and return the best text we heard so far
    func stopAndFlush() -> String {
        let text = latestText.trimmingCharacters(in: .whitespacesAndNewlines)
        stopListening(cleanSession: false)
        return text
    }

    /// Hard reset before a brand-new interaction
    func reset() {
        endWorkItem?.cancel(); endWorkItem = nil
        latestText = ""
        stopListening(cleanSession: true)
    }
    
    /// Clear just the text without stopping session (faster)
    func clearLatestText() {
        endWorkItem?.cancel(); endWorkItem = nil
        latestText = ""
    }
}

