import SwiftUI
import GoogleMaps

struct GoogleMapView: UIViewRepresentable {
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: 37.7749, longitude: -122.4194, zoom: 12)
        let mapView = GMSMapView(frame: .zero)
        mapView.camera = camera
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        return mapView
    }
    func updateUIView(_ uiView: GMSMapView, context: Context) { }
}

struct ContentView: View {
    @StateObject private var listener = SpeechListener()
    private let talker = VoiceTalker()

    @State private var transcript: String = ""
    @State private var isListening = false
    @State private var autoLoop = false   // keep listening after we speak

    var body: some View {
        ZStack(alignment: .bottom) {
            GoogleMapView().ignoresSafeArea()

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
                        isListening = true
                        transcript = ""
                        listener.reset() // optional: clear last transcript
                        listener.prewarmAudioSession()
                        startListening()
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
        }
    } // <-- close the body here

    private func startListening() {
        if isListening == false { isListening = true } // for safety

        listener.requestPermissions { ok in
            guard ok else {
                isListening = false
                talker.say("I need microphone and speech permissions.")
                return
            }
            do {
                try listener.startListening { text, isFinal in
                    transcript = text
                    if isFinal {
                        isListening = false
                        respond(to: text)
                    }
                }
            } catch {
                isListening = false
                talker.say("Sorry, I couldn't start listening.")
            }
        }
    }

    private func respond(to text: String) {
        // placeholder echo; later we’ll parse and call Google Places
        talker.say("You said \(text)")
    }
}
