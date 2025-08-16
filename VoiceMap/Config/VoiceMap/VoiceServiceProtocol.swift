import Foundation

protocol VoiceServiceProtocol {
    func processVoiceRequest(_ request: VoiceRequest) async throws -> AIAudioResponse
    func startListening() async throws
    func stopListening()
    func setVoice(_ voice: String)
}

// Voice response that works for both TTS and Realtime
struct VoiceResponse {
    let text: String
    let audioData: Data?
    let isStreaming: Bool
    
    init(text: String, audioData: Data? = nil, isStreaming: Bool = false) {
        self.text = text
        self.audioData = audioData
        self.isStreaming = isStreaming
    }
}

// Delegate for real-time voice events
protocol VoiceServiceDelegate: AnyObject {
    func voiceServiceDidStartSpeaking()
    func voiceServiceDidStopSpeaking()
    func voiceServiceDidReceiveResponse(_ response: VoiceResponse)
    func voiceServiceDidEncounterError(_ error: Error)
}