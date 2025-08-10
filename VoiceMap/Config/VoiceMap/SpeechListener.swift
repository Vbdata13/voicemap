import Foundation
import AVFoundation
import Speech

final class SpeechListener: NSObject, ObservableObject {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var didCachePermissions = false
    private var cachedPermissionsOK = false

    // silence detection
    private var endWorkItem: DispatchWorkItem?
    private let endDelay: TimeInterval = 0.8  // stop ~0.8s after last speech

    // latest text so UI can use it if user taps Stop before final result
    private(set) var latestText: String = ""

    // MARK: - Permissions

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        // If we already have a decision, return it immediately
        if didCachePermissions {
            completion(cachedPermissionsOK)
            return
        }

        // If both are already granted, short-circuit
        if SFSpeechRecognizer.authorizationStatus() == .authorized &&
            AVAudioSession.sharedInstance().recordPermission == .granted {
            didCachePermissions = true
            cachedPermissionsOK = true
            completion(true)
            return
        }

        // Otherwise ask
        SFSpeechRecognizer.requestAuthorization { auth in
            AVAudioSession.sharedInstance().requestRecordPermission { micOK in
                let ok = (auth == .authorized && micOK)
                DispatchQueue.main.async {
                    self.didCachePermissions = true
                    self.cachedPermissionsOK = ok
                    completion(ok)
                }
            }
        }
    }


    // MARK: - Session helpers

    /// Keep session simple and stable. We also call this in `startListening()`
    func prewarmAudioSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord,
                           mode: .voiceChat,
                           options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .duckOthers])
        try? s.setActive(true, options: .notifyOthersOnDeactivation)
        audioEngine.prepare()   // <-- this primes the IO so start is instant
    }

    // MARK: - Start / Stop
    private func ensureMicRoute() throws {
        let s = AVAudioSession.sharedInstance()
        // Keep the same low-latency voice chat setup we use elsewhere
        try? s.setCategory(.playAndRecord,
                           mode: .voiceChat,
                           options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .duckOthers])
        try s.setActive(true, options: []) // make sure session is active now

        // ✅ Guard: if there is no input route, bail with a clean error
        if !s.isInputAvailable || s.currentRoute.inputs.isEmpty {
            throw NSError(domain: "Speech", code: -100,
                          userInfo: [NSLocalizedDescriptionKey: "No microphone input route"])
        }
    }
    /// Begin recognition; `onText` is called with (partialText, isFinal)
    func startListening(onText: @escaping (String, Bool) -> Void) throws {
        try ensureMicRoute()
        guard recognizer?.isAvailable == true else {
            throw NSError(domain: "Speech", code: -1)
        }

        // don’t fully tear down the session (keeps it warm)
        stopListening(cleanSession: false)

        // fresh request
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true {
            req.requiresOnDeviceRecognition = true
        }
        req.taskHint = .dictation
        request = req

        // tap the mic BEFORE starting the engine
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.request?.append(buffer)
        }

        // start engine right away (instant because prewarmed)
        if !audioEngine.isRunning {
            audioEngine.prepare()
            try audioEngine.start()
        }

        // recognition
        task = recognizer?.recognitionTask(with: req) { result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                onText(text, false)  // partial

                // silence auto-stop
                self.endWorkItem?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    onText(text, true)
                    self.stopListening(cleanSession: false)
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

    /// Stop streaming; optionally tear down the session (for fully fresh restarts)
    func stopListening(cleanSession: Bool) {
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
}

