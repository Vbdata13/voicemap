import Foundation
import AVFoundation

final class VoiceTalker: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    private var audioPlayer: AVAudioPlayer?
    var onFinish: (() -> Void)?
    
    // Fallback to Apple TTS for error cases
    private let fallbackSynth = AVSpeechSynthesizer()
    private var selectedVoice: AVSpeechSynthesisVoice?

    override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        
        // Set default fallback voice
        setVoice(identifier: "com.apple.ttsbundle.Samantha-compact")
    }

    // Play OpenAI audio
    func playAudio(_ audioData: Data) {
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            
            print("🎵 Playing OpenAI TTS audio")
        } catch {
            print("⚠️ Failed to play OpenAI audio: \(error)")
            // Could add fallback here if needed
        }
    }
    
    // Fallback to Apple TTS
    func say(_ text: String) {
        let u = AVSpeechUtterance(string: text)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        u.pitchMultiplier = 1.0
        u.postUtteranceDelay = 0.05
        u.voice = selectedVoice
        
        print("🍎 Using Apple TTS fallback")
        fallbackSynth.speak(u)
    }
    
    func stop() {
        audioPlayer?.stop()
        fallbackSynth.stopSpeaking(at: .immediate)
    }

    // MARK: - Audio Player Delegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
    
    // MARK: - Voice Selection (for Apple TTS fallback)
    
    func setVoice(identifier: String) {
        selectedVoice = AVSpeechSynthesisVoice(identifier: identifier)
    }
    
    func setVoice(_ voice: AVSpeechSynthesisVoice) {
        selectedVoice = voice
    }
    
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
    }
    
    func getCurrentVoice() -> AVSpeechSynthesisVoice? {
        return selectedVoice
    }
}

