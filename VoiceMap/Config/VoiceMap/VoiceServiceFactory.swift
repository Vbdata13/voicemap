import Foundation

class VoiceServiceFactory {
    static func createService(mode: VoiceMode) -> VoiceServiceProtocol {
        switch mode {
        case .tts:
            return TTSAIService()
        case .realtime:
            return RealtimeAIService()
        }
    }
}

// Wrapper for existing AIService to conform to protocol
class TTSAIService: VoiceServiceProtocol {
    private let aiService = AIService()
    
    func processVoiceRequest(_ request: VoiceRequest) async throws -> AIAudioResponse {
        return try await aiService.processVoiceRequest(request)
    }
    
    func startListening() async throws {
        // TTS mode doesn't need persistent listening
        print("🎤 TTS mode: Ready for voice input")
    }
    
    func stopListening() {
        // TTS mode doesn't need to stop listening
        print("🎤 TTS mode: Stopped")
    }
    
    func setVoice(_ voice: String) {
        // Map to OpenAI TTS voices
        if let openAIVoice = OpenAIVoice(rawValue: voice) {
            aiService.selectedVoice = openAIVoice
            print("🎵 TTS voice set to: \(openAIVoice.displayName)")
        }
    }
}