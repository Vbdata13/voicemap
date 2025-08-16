import SwiftUI
import GoogleMaps

struct GoogleMapView: UIViewRepresentable {
    @ObservedObject var locationProvider: LocationProvider
    
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: 37.7749, longitude: -122.4194, zoom: 12)
        let mapView = GMSMapView(frame: .zero)
        mapView.camera = camera
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        return mapView
    }
    
    func updateUIView(_ uiView: GMSMapView, context: Context) {
        if let location = locationProvider.currentLocation {
            let camera = GMSCameraPosition.camera(
                withLatitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                zoom: 15
            )
            uiView.animate(to: camera)
        }
    }
}

struct ContentView: View {
    @StateObject private var listener = SpeechListener()
    @StateObject private var locationProvider = LocationProvider()
    @StateObject private var voiceConfig = VoiceConfig.shared
    private let talker = VoiceTalker()
    
    // Voice service changes based on mode
    private var voiceService: VoiceServiceProtocol {
        VoiceServiceFactory.createService(mode: voiceConfig.currentMode)
    }

    @State private var transcript: String = ""
    @State private var aiResponse: String = "" // Show AI response even if TTS fails
    @State private var isListening = false
    @State private var autoLoop = false   // keep listening after we speak
    @State private var currentAITask: Task<Void, Never>?
    @State private var isProcessingAI = false
    @State private var isStopped = false

    var body: some View {
        ZStack(alignment: .bottom) {
            GoogleMapView(locationProvider: locationProvider).ignoresSafeArea()

            VStack(spacing: 12) {
                // Mode indicator
                HStack {
                    Image(systemName: voiceConfig.isRealtimeMode ? "waveform" : "speaker.wave.2")
                        .foregroundColor(voiceConfig.isRealtimeMode ? .green : .blue)
                    Text(voiceConfig.currentMode.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Mode switcher
                    Button(voiceConfig.isRealtimeMode ? "Switch to TTS" : "Switch to Realtime") {
                        let newMode: VoiceMode = voiceConfig.isRealtimeMode ? .tts : .realtime
                        voiceConfig.setMode(newMode)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
                .padding(.horizontal)
                
                if !transcript.isEmpty {
                    Text("You said: \(transcript)")
                        .font(.callout)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                if !aiResponse.isEmpty {
                    Text("AI Response: \(aiResponse)")
                        .font(.callout)
                        .padding(10)
                        .background(.blue.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(.black)
                }

                HStack(spacing: 12) {
                    Button(isListening ? "Listening…" : "Start Listening") {
                        // Set listening state immediately for instant UI feedback
                        isListening = true
                        transcript = ""
                        aiResponse = "" // Clear previous response
                        isStopped = false
                        
                        // Do minimal setup synchronously (avoid session deactivate/activate cycle)
                        listener.stopListening(cleanSession: false) // Keep session active
                        listener.clearLatestText()
                        
                        do {
                            try listener.startListening { text, isFinal in
                                DispatchQueue.main.async {
                                    transcript = text
                                    if isFinal {
                                        isListening = false
                                        respond(to: text)
                                    }
                                }
                            }
                        } catch {
                            isListening = false
                            talker.say("Sorry, I couldn't start listening.")
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(isListening ? .green.opacity(0.9) : .black.opacity(0.85))
                    .foregroundColor(.white).clipShape(Capsule())

                    Button("Stop") {
                        let wasProcessingAI = isProcessingAI
                        
                        // Mark as stopped to prevent any pending responses
                        isStopped = true
                        
                        // Cancel any ongoing AI request
                        currentAITask?.cancel()
                        currentAITask = nil
                        isProcessingAI = false
                        
                        // Stop any ongoing speech
                        talker.stop()
                        
                        let text = listener.stopAndFlush()
                        isListening = false
                        
                        // Only process speech if we weren't already processing an AI request
                        if !text.isEmpty && !wasProcessingAI {
                            respond(to: text)
                        } else if text.isEmpty && !wasProcessingAI {
                            talker.say("I didn't catch that.")
                        }
                        // If we cancelled an AI request, just stop - don't start a new one
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.gray.opacity(0.8)).foregroundColor(.white).clipShape(Capsule())
                    
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            listener.prewarmAudioSession()
            locationProvider.requestLocation()
        }
    } // <-- close the body here


    private func respond(to text: String) {
        guard let location = locationProvider.currentLocation else {
            talker.say("Location not available. You said \(text)")
            return
        }
        
        // Don't start new request if already processing
        guard !isProcessingAI else { return }
        
        let request = VoiceRequest(speech: text, location: location)
        
        // Cancel any existing AI request
        currentAITask?.cancel()
        
        isProcessingAI = true
        
        // No processing feedback - let AI respond naturally
        
        currentAITask = Task {
            do {
                let audioResponse = try await voiceService.processVoiceRequest(request)
                if !Task.isCancelled && !isStopped {
                    await MainActor.run {
                        if !isStopped {
                            aiResponse = audioResponse.text // Show response text in UI
                            print("🎯 [\(voiceConfig.currentMode.rawValue.uppercased())] Response: \(audioResponse.text)")
                            
                            // Handle response based on mode
                            if voiceConfig.isRealtimeMode {
                                // Realtime mode handles audio streaming internally
                                if !audioResponse.audioData.isEmpty {
                                    talker.playAudio(audioResponse.audioData)
                                } else {
                                    print("🔄 Realtime mode: audio handled by service")
                                }
                            } else {
                                // TTS mode: check if we have audio data, otherwise fallback to Apple TTS
                                if audioResponse.audioData.isEmpty {
                                    print("🔄 Using Apple TTS fallback")
                                    talker.say(audioResponse.text)
                                } else {
                                    print("🎵 Using OpenAI TTS")
                                    talker.playAudio(audioResponse.audioData)
                                }
                            }
                        }
                        currentAITask = nil
                        isProcessingAI = false
                    }
                }
            } catch {
                if !Task.isCancelled && !isStopped {
                    await MainActor.run {
                        if !isStopped {
                            talker.say("Sorry, I couldn't process your request right now. Please try again.")
                        }
                        currentAITask = nil
                        isProcessingAI = false
                    }
                    print("AI Service error: \(error)")
                }
            }
        }
    }
}
