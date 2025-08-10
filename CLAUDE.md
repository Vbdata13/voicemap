# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Running
- **Xcode**: Open `VoiceMap/VoiceMap.xcodeproj` and use Xcode's standard build/run commands (⌘R)
- **Build**: Use Xcode's Product > Build (⌘B) or build via command line with `xcodebuild`
- **Testing**: Run unit tests with `VoiceMapTests` target, UI tests with `VoiceMapUITests` target

### Dependencies
- Google Maps SDK is managed via Swift Package Manager (configured in project.pbxproj)
- No additional package managers (CocoaPods, Carthage) are used

## Project Architecture

### Core Structure
This is a SwiftUI-based iOS voice assistant app that integrates location services with Google Maps. The app allows users to interact via voice commands with map functionality.

### Key Components

**`ContentView.swift`** - Main UI view that orchestrates the voice interaction flow:
- Integrates `SpeechListener` for voice input, `LocationProvider` for location services, and `VoiceTalker` for speech output
- Contains `GoogleMapView` (UIViewRepresentable wrapper for Google Maps)
- Handles the voice interaction lifecycle: listening → processing → responding

**`SpeechListener.swift`** - Speech recognition management:
- Handles iOS speech recognition permissions and audio session configuration
- Uses `SFSpeechRecognizer` and `AVAudioEngine` for real-time speech transcription
- Implements audio session prewarming for faster start times
- Provides both streaming (partial) and final results

**`LocationProvider.swift`** - Core Location wrapper:
- ObservableObject that publishes user location updates via `@Published coordinate`
- Configured for ~5m distance filtering and "nearest ten meters" accuracy
- Handles location authorization and updates

**`VoiceTalker.swift`** - Text-to-speech output:
- Uses `AVSpeechSynthesizer` for voice responses
- Configured with mixed audio session for simultaneous playback during recording

**`VoiceMapApp.swift`** - App entry point:
- Initializes Google Maps SDK with API key from `AppSecrets`

**`AppSecrets.swift`** - Configuration:
- Contains Google Maps API key (should be kept secure in production)

### Data Flow
1. User taps "Start Listening" → `SpeechListener` begins real-time transcription
2. Speech is converted to text and displayed in UI
3. On completion (final result or Stop button), text is passed to `respond(to:)` 
4. Currently responds with simple echo via `VoiceTalker` (placeholder for future Google Places integration)

### Dependencies & Frameworks
- **SwiftUI**: Primary UI framework
- **GoogleMaps**: Map display and interaction
- **CoreLocation**: User location services  
- **Speech/AVFoundation**: Voice recognition and speech synthesis

### Current Limitations
- Voice response is placeholder echo - not integrated with Google Places API yet
- No persistent data storage
- Single-session voice interactions (no conversation context)