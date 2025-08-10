import Foundation
import AVFoundation

final class VoiceTalker: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synth = AVSpeechSynthesizer()
    var onFinish: (() -> Void)?
    
    // Voice selection
    private var selectedVoice: AVSpeechSynthesisVoice?

    override init() {
        super.init()
        synth.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        
        // Set default voice to a nice English voice
        setVoice(identifier: "com.apple.ttsbundle.Samantha-compact")
    }

    func say(_ text: String) {
        let u = AVSpeechUtterance(string: text)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        u.pitchMultiplier = 1.0
        u.postUtteranceDelay = 0.05
        
        // Set voice if selected
        u.voice = selectedVoice
        
        synth.speak(u)
    }
    
    func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }
    
    // MARK: - Voice Selection
    
    func setVoice(identifier: String) {
        selectedVoice = AVSpeechSynthesisVoice(identifier: identifier)
    }
    
    func setVoice(_ voice: AVSpeechSynthesisVoice) {
        selectedVoice = voice
    }
    
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") } // English voices only
            .sorted { $0.name < $1.name }
    }
    
    func getCurrentVoice() -> AVSpeechSynthesisVoice? {
        return selectedVoice
    }
}

