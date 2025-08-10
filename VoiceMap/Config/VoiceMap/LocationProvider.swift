import Foundation
import CoreLocation

final class LocationProvider: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        default:
            break
        }
    }
    
    private func startLocationUpdates() {
        manager.startUpdatingLocation()
        print("Started continuous location updates")
    }
    
    func stopLocationUpdates() {
        manager.stopUpdatingLocation()
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let newLocation = locations.last {
            currentLocation = newLocation
            print("Location updated: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            startLocationUpdates()
        }
    }
}