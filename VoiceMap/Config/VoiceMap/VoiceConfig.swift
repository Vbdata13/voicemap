import Foundation

enum VoiceMode: String, CaseIterable {
    case tts = "tts"
    case realtime = "realtime"
    case livekit = "livekit"
    
    var displayName: String {
        switch self {
        case .tts:
            return "TTS Mode (Stable)"
        case .realtime:
            return "Realtime Mode (Interactive)"
        case .livekit:
            return "LiveKit Mode (Optimized)"
        }
    }
    
    var description: String {
        switch self {
        case .tts:
            return "High-quality text-to-speech with OpenAI voices"
        case .realtime:
            return "Real-time conversation with voice interruption"
        case .livekit:
            return "Optimized real-time via LiveKit + OpenAI"
        }
    }
}

class VoiceConfig: ObservableObject {
    static let shared = VoiceConfig()
    
    @Published var currentMode: VoiceMode = .tts
    
    private let userDefaults = UserDefaults.standard
    private let modeKey = "voice_mode"
    
    private init() {
        // Load saved mode
        if let savedMode = userDefaults.string(forKey: modeKey),
           let mode = VoiceMode(rawValue: savedMode) {
            currentMode = mode
        }
    }
    
    func setMode(_ mode: VoiceMode) {
        currentMode = mode
        userDefaults.set(mode.rawValue, forKey: modeKey)
        print("🔧 Voice mode changed to: \(mode.displayName)")
    }
    
    var isRealtimeMode: Bool {
        return currentMode == .realtime
    }
    
    var isTTSMode: Bool {
        return currentMode == .tts
    }
}