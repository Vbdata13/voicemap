import Foundation
import CoreLocation

struct PlaceResult: Codable {
    let placeId: String
    let name: String
    let vicinity: String?
    let rating: Double?
    let userRatingsTotal: Int?
    let priceLevel: Int?
    let isOpen: Bool?
    let location: PlaceLocation
    let types: [String]
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name
        case vicinity
        case rating
        case userRatingsTotal = "user_ratings_total"
        case priceLevel = "price_level"
        case isOpen = "open_now"
        case location = "geometry"
        case types
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        placeId = try container.decode(String.self, forKey: .placeId)
        name = try container.decode(String.self, forKey: .name)
        vicinity = try container.decodeIfPresent(String.self, forKey: .vicinity)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        userRatingsTotal = try container.decodeIfPresent(Int.self, forKey: .userRatingsTotal)
        priceLevel = try container.decodeIfPresent(Int.self, forKey: .priceLevel)
        types = try container.decode([String].self, forKey: .types)
        
        let geometry = try container.decode(PlaceGeometry.self, forKey: .location)
        location = geometry.location
        
        // Extract open_now from opening_hours if present
        if let openingHours = try? container.decodeIfPresent([String: Bool].self, forKey: .isOpen) {
            isOpen = openingHours["open_now"]
        } else {
            isOpen = nil
        }
    }
}

struct PlaceGeometry: Codable {
    let location: PlaceLocation
}

struct PlaceLocation: Codable {
    let lat: Double
    let lng: Double
}

struct PlacesResponse: Codable {
    let results: [PlaceResult]
    let status: String
}

class GooglePlacesService {
    private let apiKey: String
    private let session = URLSession.shared
    
    init() {
        self.apiKey = AppSecrets.googleAPIKey
    }
    
    func searchNearby(query: String, location: CLLocation, radius: Int = 5000) async throws -> [PlaceResult] {
        let baseURL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "keyword", value: query),
            URLQueryItem(name: "location", value: "\(location.coordinate.latitude),\(location.coordinate.longitude)"),
            URLQueryItem(name: "radius", value: String(radius)),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw NSError(domain: "GooglePlaces", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        print("Places API URL: \(url)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GooglePlaces", code: 2, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
        }
        
        print("Places API Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Places API Error Response: \(responseString)")
            }
            throw NSError(domain: "GooglePlaces", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Places API request failed"])
        }
        
        let placesResponse = try JSONDecoder().decode(PlacesResponse.self, from: data)
        
        if placesResponse.status != "OK" && placesResponse.status != "ZERO_RESULTS" {
            throw NSError(domain: "GooglePlaces", code: 3, userInfo: [NSLocalizedDescriptionKey: "Places API returned status: \(placesResponse.status)"])
        }
        
        return placesResponse.results
    }
    
    func formatPlacesForAI(places: [PlaceResult], userLocation: CLLocation) -> String {
        if places.isEmpty {
            return "No places found for this search."
        }
        
        var result = "Found \(places.count) places:\n"
        
        for (index, place) in places.prefix(5).enumerated() {
            let placeLocation = CLLocation(latitude: place.location.lat, longitude: place.location.lng)
            let distance = userLocation.distance(from: placeLocation)
            let distanceText = distance < 1000 ? String(format: "%.0fm", distance) : String(format: "%.1fkm", distance/1000)
            
            result += "\(index + 1). \(place.name)"
            if let vicinity = place.vicinity {
                result += " at \(vicinity)"
            }
            result += " - \(distanceText) away"
            if let rating = place.rating {
                result += ", rated \(rating) stars"
            }
            if let isOpen = place.isOpen {
                result += isOpen ? " (open now)" : " (closed now)"
            }
            result += "\n"
        }
        
        return result
    }
}