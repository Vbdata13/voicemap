//
//  VoiceMapApp.swift
//  VoiceMap
//
//  Created by Vignesh Balaji on 8/9/25.
//
//
//  VoiceMapApp.swift
//  VoiceMap
//
//  Created by Vignesh Balaji on 8/9/25.
//

import SwiftUI
import GoogleMaps  // ✅ Add this

@main
struct VoiceMapApp: App {
    
    // ✅ Add init() to provide Google Maps API key
    init() {
        GMSServices.provideAPIKey(AppSecrets.googleAPIKey)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

