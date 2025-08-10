import Foundation
import CoreLocation

struct VoiceRequest: Codable {
    let speech: String
    let location: LocationData
    let timestamp: Date
    
    init(speech: String, location: CLLocation) {
        self.speech = speech
        self.location = LocationData(from: location)
        self.timestamp = Date()
    }
}

struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    
    init(from location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.accuracy = location.horizontalAccuracy
    }
}