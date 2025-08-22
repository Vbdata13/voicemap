import Foundation
import LiveKit
import CoreLocation
import CommonCrypto

class LiveKitVoiceService: NSObject, VoiceServiceProtocol {
    private var room: Room?
    private var localParticipant: LocalParticipant?
    private var isConnected = false
    private var isListening = false
    
    var delegate: VoiceServiceDelegate?
    
    // LiveKit configuration - Using secure configuration
    private let apiKey = AppSecrets.liveKitAPIKey
    private let apiSecret = AppSecrets.liveKitAPISecret
    private let serverURL = AppSecrets.liveKitURL
    
    override init() {
        super.init()
        setupRoom()
    }
    
    // MARK: - VoiceServiceProtocol
    
    func processVoiceRequest(_ request: VoiceRequest) async throws -> AIAudioResponse {
        if !isConnected {
            try await connectToRoom()
        }
        
        return AIAudioResponse(text: "LiveKit session active. Start speaking!", audioData: Data())
    }
    
    func startListening() async throws {
        print("🎙️ Starting LiveKit voice session...")
        
        if !isConnected {
            try await connectToRoom()
        }
        
        // Enable microphone using updated API
        try await localParticipant?.setMicrophone(enabled: true)
        isListening = true
        
        delegate?.voiceServiceDidStartSpeaking()
        print("✅ LiveKit microphone enabled")
    }
    
    func stopListening() {
        print("🔇 Stopping LiveKit voice session...")
        
        Task {
            try await localParticipant?.setMicrophone(enabled: false)
        }
        
        isListening = false
        delegate?.voiceServiceDidStopSpeaking()
    }
    
    func setVoice(_ voice: String) {
        print("🎵 LiveKit voice setting: \(voice) (handled by backend agent)")
    }
    
    func disconnect() {
        print("🔌 Disconnecting from LiveKit...")
        
        Task {
            await room?.disconnect()
        }
        
        isConnected = false
        isListening = false
    }
    
    // MARK: - LiveKit Setup
    
    private func setupRoom() {
        room = Room()
        room?.add(delegate: self)
    }
    
    private func connectToRoom() async throws {
        guard let room = room else {
            throw NSError(domain: "LiveKitVoiceService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Room not initialized"])
        }
        
        print("🔗 Connecting to LiveKit room...")
        
        // Generate access token
        let token = generateAccessToken()
        
        // Updated ConnectOptions for current API
        let connectOptions = ConnectOptions(
            autoSubscribe: true
        )
        
        try await room.connect(
            url: serverURL,
            token: token,
            connectOptions: connectOptions
        )
        
        localParticipant = room.localParticipant
        isConnected = true
        
        print("✅ Connected to LiveKit room")
    }
    
    // MARK: - Token Generation
    
    private func generateAccessToken() -> String {
        let now = Date()
        let exp = now.addingTimeInterval(24 * 60 * 60) // 24 hours from now
        
        let header = [
            "alg": "HS256",
            "typ": "JWT"
        ]
        
        let payload = [
            "iss": apiKey,
            "sub": "ios-user",
            "aud": "voicemap-room",
            "exp": Int(exp.timeIntervalSince1970),
            "nbf": Int(now.timeIntervalSince1970),
            "iat": Int(now.timeIntervalSince1970),
            "video": [
                "room": "voicemap-room",
                "roomJoin": true,
                "canPublish": true,
                "canSubscribe": true,
                "canPublishData": true
            ]
        ] as [String: Any]
        
        do {
            return try createJWT(header: header, payload: payload, secret: apiSecret)
        } catch {
            print("❌ Failed to generate JWT token: \(error)")
            // Fallback to existing token for now
            return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJBUElRSEJ3Sm10ZE15VFgiLCJzdWIiOiJpb3MtdXNlciIsImF1ZCI6InZvaWNlbWFwLXJvb20iLCJleHAiOjE3NTU1MTM2OTksIm5iZiI6MTc1NTQyNzI5OSwiaWF0IjoxNzU1NDI3Mjk5LCJ2aWRlbyI6eyJyb29tIjoidm9pY2VtYXAtcm9vbSIsInJvb21Kb2luIjp0cnVlLCJjYW5QdWJsaXNoIjp0cnVlLCJjYW5TdWJzY3JpYmUiOnRydWUsImNhblB1Ymxpc2hEYXRhIjp0cnVlfX0.vEkIAVpeRN3jkTlDS1-pSvvwyQPxpPR2KuzE50CFXTY"
        }
    }
    
    private func createJWT(header: [String: Any], payload: [String: Any], secret: String) throws -> String {
        let headerData = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        
        let headerBase64 = headerData.base64URLEncodedString()
        let payloadBase64 = payloadData.base64URLEncodedString()
        
        let signingString = "\(headerBase64).\(payloadBase64)"
        let signature = try hmacSHA256(data: signingString, key: secret)
        let signatureBase64 = signature.base64URLEncodedString()
        
        return "\(signingString).\(signatureBase64)"
    }
    
    private func hmacSHA256(data: String, key: String) throws -> Data {
        let keyData = key.data(using: .utf8)!
        let dataData = data.data(using: .utf8)!
        
        var result = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        
        result.withUnsafeMutableBytes { resultBytes in
            dataData.withUnsafeBytes { dataBytes in
                keyData.withUnsafeBytes { keyBytes in
                    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                           keyBytes.bindMemory(to: UInt8.self).baseAddress, keyData.count,
                           dataBytes.bindMemory(to: UInt8.self).baseAddress, dataData.count,
                           resultBytes.bindMemory(to: UInt8.self).baseAddress)
                }
            }
        }
        
        return result
    }
}

// MARK: - Base64URL Extensions

extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - RoomDelegate

extension LiveKitVoiceService: RoomDelegate {
    func roomDidConnect(_ room: Room) {
        print("🏠 Room connected")
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.voiceServiceDidStartSpeaking()
        }
    }
    
    func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        print("🚪 Room disconnected, error: \(String(describing: error))")
        
        isConnected = false
        isListening = false
        
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.voiceServiceDidEncounterError(error)
            }
        }
    }
    
    func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String) {
        print("📨 Received data from participant: \(String(describing: participant?.identity))")
        
        // Handle any data messages from the agent
        if let message = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.voiceServiceDidReceiveResponse(VoiceResponse(
                    text: message,
                    audioData: nil,
                    isStreaming: false
                ))
            }
        }
    }
    
    func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        print("🎵 Subscribed to track: \(String(describing: publication.track?.kind))")
        
        if publication.track?.kind == .audio {
            print("🔊 Receiving audio from AI agent")
            
            // The audio will be played automatically by LiveKit
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.voiceServiceDidReceiveResponse(VoiceResponse(
                    text: "AI is speaking...",
                    audioData: nil,
                    isStreaming: true
                ))
            }
        }
    }
}