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
    private let talker = VoiceTalker()

    @State private var transcript: String = ""
    @State private var isListening = false
    @State private var autoLoop = false   // keep listening after we speak

    var body: some View {
        ZStack(alignment: .bottom) {
            GoogleMapView(locationProvider: locationProvider).ignoresSafeArea()

            VStack(spacing: 12) {
                if !transcript.isEmpty {
                    Text(transcript)
                        .font(.callout)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 12) {
                    Button(isListening ? "Listening…" : "Start Listening") {
                        // Set listening state immediately for instant UI feedback
                        isListening = true
                        transcript = ""
                        
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
                        let text = listener.stopAndFlush()
                        isListening = false
                        if !text.isEmpty {
                            respond(to: text)
                        } else {
                            talker.say("I didn't catch that.")
                        }
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
        
        let request = VoiceRequest(speech: text, location: location)
        
        // For now, just announce the captured data
        talker.say("Got your request at latitude \(String(format: "%.4f", request.location.latitude)), longitude \(String(format: "%.4f", request.location.longitude)). You said: \(text)")
        
        // TODO: Send request to AI backend
        print("VoiceRequest created: \(request)")
    }
}
