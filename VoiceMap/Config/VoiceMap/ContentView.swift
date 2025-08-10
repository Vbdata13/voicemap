import SwiftUI
import GoogleMaps
import CoreLocation
import AVFoundation

struct GoogleMapView: UIViewRepresentable {
    var userLocation: CLLocationCoordinate2D?

    // Keep state for this UIKit view
    class Coordinator {
        var lastCentered: CLLocationCoordinate2D?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView(frame: .zero)
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {
        guard let loc = userLocation else { return }

        // If we never centered, or the location changed enough, animate the camera.
        if shouldRecenter(from: context.coordinator.lastCentered, to: loc) {
            let camera = GMSCameraPosition.camera(withTarget: loc, zoom: 14)
            uiView.animate(to: camera)
            context.coordinator.lastCentered = loc
        }
    }

    // Only recenter if we don't have a previous fix, or we've moved > ~5 meters
    private func shouldRecenter(from old: CLLocationCoordinate2D?, to new: CLLocationCoordinate2D) -> Bool {
        guard let old = old else { return true }
        let d = CLLocation(latitude: old.latitude, longitude: old.longitude)
            .distance(from: CLLocation(latitude: new.latitude, longitude: new.longitude))
        return d > 5
    }
}

struct ContentView: View {
    @StateObject private var listener = SpeechListener()
    @StateObject private var location = LocationProvider()
    private let talker = VoiceTalker()

    @State private var transcript: String = ""
    @State private var isListening = false
    @State private var autoLoop = false   // keep listening after we speak

    var body: some View {
        ZStack(alignment: .bottom) {
            GoogleMapView(userLocation: location.coordinate)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                if !transcript.isEmpty {
                    Text(transcript)
                        .font(.callout)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if let c = location.coordinate {
                    Text(String(format: "lat: %.5f, lng: %.5f", c.latitude, c.longitude))
                        .font(.footnote)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 12) {
                    Button(isListening ? "Listening…" : "Start Listening") {
                        isListening = true
                        transcript = ""
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
            // listener.prewarmAudioSession()     // <-- important: warm audio so start is instant
            talker.onFinish = {
                if autoLoop {
                    DispatchQueue.main.async { startListening() }
                }
            }
        }
    } // <-- close the body here

    private func startListening() {
        listener.requestPermissions { ok in
            guard ok else {
                talker.say("I need microphone and speech permissions.")
                return
            }
            try? AVAudioSession.sharedInstance().setActive(true, options: [])

            // instant UI feedback
            isListening = true
            transcript = ""

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
