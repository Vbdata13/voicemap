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
        
        print("🔍 GooglePlaces searching for: '\(query)' at \(location.coordinate.latitude),\(location.coordinate.longitude) within \(radius)m")
        
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
        
        print("📍 Places API found \(placesResponse.results.count) results with status: \(placesResponse.status)")
        for (i, place) in placesResponse.results.prefix(3).enumerated() {
            let distance = location.distance(from: CLLocation(latitude: place.location.lat, longitude: place.location.lng))
            print("  \(i+1). \(place.name) - \(String(format: "%.0f", distance))m away")
        }
        
        if placesResponse.status != "OK" && placesResponse.status != "ZERO_RESULTS" {
            throw NSError(domain: "GooglePlaces", code: 3, userInfo: [NSLocalizedDescriptionKey: "Places API returned status: \(placesResponse.status)"])
        }
        
        return placesResponse.results
    }
    
    // MARK: - Place Details API
    
    func getPlaceDetails(placeId: String) async throws -> PlaceDetails {
        let baseURL = "https://maps.googleapis.com/maps/api/place/details/json"
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "place_id", value: placeId),
            URLQueryItem(name: "fields", value: "place_id,name,rating,reviews,formatted_phone_number,website,opening_hours,price_level,photos"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw NSError(domain: "GooglePlaces", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for place details"])
        }
        
        print("Place Details API URL: \(url)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GooglePlaces", code: 2, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
        }
        
        print("Place Details API Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Place Details API Error Response: \(responseString)")
            }
            throw NSError(domain: "GooglePlaces", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Place Details API request failed"])
        }
        
        let decoder = JSONDecoder()
        let placeDetailsResponse = try decoder.decode(PlaceDetailsResponse.self, from: data)
        
        if placeDetailsResponse.status != "OK" {
            throw NSError(domain: "GooglePlaces", code: 3, userInfo: [NSLocalizedDescriptionKey: "Place Details API returned status: \(placeDetailsResponse.status)"])
        }
        
        return placeDetailsResponse.result
    }
    
    // MARK: - Review Analysis
    
    func analyzeReviews(placeId: String, keywords: [String], limit: Int = 10) async throws -> ReviewAnalysis {
        let placeDetails = try await getPlaceDetails(placeId: placeId)
        
        let relevantReviews = placeDetails.reviews.prefix(limit)
        var keywordMatches = 0
        var relevantTexts: [String] = []
        var evidence: [String] = []
        
        for review in relevantReviews {
            let reviewText = review.text.lowercased()
            
            for keyword in keywords {
                if reviewText.contains(keyword.lowercased()) {
                    keywordMatches += 1
                    relevantTexts.append(review.text)
                    
                    // Extract sentence containing keyword for evidence
                    let sentences = review.text.components(separatedBy: ". ")
                    for sentence in sentences {
                        if sentence.lowercased().contains(keyword.lowercased()) {
                            evidence.append("\"\(sentence.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                            break
                        }
                    }
                    break
                }
            }
        }
        
        // Calculate scores
        let totalReviews = Double(relevantReviews.count)
        let matchPercentage = totalReviews > 0 ? Double(keywordMatches) / totalReviews : 0.0
        let confidenceScore = min(1.0, matchPercentage * 2.0) // Scale confidence
        let attributeScore = matchPercentage
        
        return ReviewAnalysis(
            placeId: placeId,
            keywordMatches: keywordMatches,
            sentimentScore: 0.5, // Placeholder - could implement sentiment analysis
            confidenceScore: confidenceScore,
            relevantReviews: Array(relevantTexts.prefix(3)), // Top 3 relevant reviews
            attributeScore: attributeScore,
            evidence: Array(evidence.prefix(3)) // Top 3 evidence quotes
        )
    }
    
    // MARK: - Intelligent Search
    
    func intelligentSearch(strategy: DataStrategy, location: CLLocation, radius: Int = 5000) async throws -> [EnhancedPlaceResult] {
        var enhancedResults: [EnhancedPlaceResult] = []
        
        // Step 1: Basic nearby search
        let searchQuery = strategy.searchTerms.joined(separator: " OR ")
        let basicPlaces = try await searchNearby(query: searchQuery, location: location, radius: radius)
        
        print("🔍 Found \(basicPlaces.count) basic places for intelligent search")
        
        // Step 2: Enhance with detailed analysis if required
        for (index, place) in basicPlaces.enumerated() {
            var reviewAnalysis: ReviewAnalysis?
            var attributeScores: [String: Double] = [:]
            var confidenceScore: Double = 0.5
            
            // Check if detailed analysis is needed
            if strategy.apiCallsNeeded.contains(.reviewsAnalysis),
               let analysisConfig = strategy.analysisRequired {
                
                do {
                    reviewAnalysis = try await analyzeReviews(
                        placeId: place.placeId,
                        keywords: analysisConfig.keywords,
                        limit: analysisConfig.reviewLimit ?? 10
                    )
                    
                    confidenceScore = reviewAnalysis?.confidenceScore ?? 0.5
                    
                    if let attrScore = reviewAnalysis?.attributeScore {
                        attributeScores[analysisConfig.sentimentFocus ?? "relevance"] = attrScore
                    }
                    
                    print("📊 Analyzed reviews for \(place.name): confidence \(String(format: "%.2f", confidenceScore))")
                    
                } catch {
                    print("⚠️ Failed to analyze reviews for \(place.name): \(error)")
                    // Continue with basic info
                }
            }
            
            let enhancedPlace = EnhancedPlaceResult(
                basicPlace: place,
                reviewAnalysis: reviewAnalysis,
                attributeScores: attributeScores.isEmpty ? nil : attributeScores,
                confidenceScore: confidenceScore,
                ranking: index + 1
            )
            
            enhancedResults.append(enhancedPlace)
        }
        
        // Step 3: Sort by confidence/relevance if analysis was performed
        if strategy.apiCallsNeeded.contains(.reviewsAnalysis) {
            enhancedResults.sort { $0.confidenceScore > $1.confidenceScore }
            
            // Update rankings after sorting
            for (index, _) in enhancedResults.enumerated() {
                enhancedResults[index] = EnhancedPlaceResult(
                    basicPlace: enhancedResults[index].basicPlace,
                    reviewAnalysis: enhancedResults[index].reviewAnalysis,
                    attributeScores: enhancedResults[index].attributeScores,
                    confidenceScore: enhancedResults[index].confidenceScore,
                    ranking: index + 1
                )
            }
        }
        
        return enhancedResults
    }
    
    // MARK: - Enhanced Formatting
    
    func formatEnhancedPlacesForAI(places: [EnhancedPlaceResult], userLocation: CLLocation, strategy: DataStrategy) -> String {
        if places.isEmpty {
            return "No places found for this search."
        }
        
        var result = "Found \(places.count) places"
        
        // Add analysis summary if complex search
        if strategy.complexity != .low {
            let analyzedCount = places.filter { $0.reviewAnalysis != nil }.count
            if analyzedCount > 0 {
                result += " (analyzed \(analyzedCount) with review data)"
            }
        }
        result += ":\n"
        
        let displayCount = strategy.responseFormat == .detailed ? 3 : 5
        
        for enhancedPlace in places.prefix(displayCount) {
            let place = enhancedPlace.basicPlace
            let placeLocation = CLLocation(latitude: place.location.lat, longitude: place.location.lng)
            let distance = userLocation.distance(from: placeLocation)
            let distanceInMiles = distance * 0.000621371 // Convert meters to miles
            let distanceText = distanceInMiles < 0.1 ? String(format: "%.0f ft", distance * 3.28084) : String(format: "%.1f mi", distanceInMiles)
            
            result += "\(enhancedPlace.ranking ?? 1). \(place.name)"
            if let vicinity = place.vicinity {
                result += " at \(vicinity)"
            }
            result += " - \(distanceText) away"
            
            if let rating = place.rating {
                result += ", rated \(rating) stars"
            }
            
            // Add analysis insights
            if let reviewAnalysis = enhancedPlace.reviewAnalysis {
                result += " (confidence: \(String(format: "%.0f", reviewAnalysis.confidenceScore * 100))%"
                
                if !reviewAnalysis.evidence.isEmpty {
                    result += ", reviews mention: \(reviewAnalysis.evidence.first!)"
                }
                result += ")"
            }
            
            if let isOpen = place.isOpen {
                result += isOpen ? " (open now)" : " (closed now)"
            }
            result += "\n"
        }
        
        return result
    }
    
    func formatPlacesForAI(places: [PlaceResult], userLocation: CLLocation) -> String {
        if places.isEmpty {
            return "No places found for this search."
        }
        
        var result = "Found \(places.count) places:\n"
        
        for (index, place) in places.prefix(5).enumerated() {
            let placeLocation = CLLocation(latitude: place.location.lat, longitude: place.location.lng)
            let distance = userLocation.distance(from: placeLocation)
            let distanceInMiles = distance * 0.000621371 // Convert meters to miles
            let distanceText = distanceInMiles < 0.1 ? String(format: "%.0f ft", distance * 3.28084) : String(format: "%.1f mi", distanceInMiles)
            
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

// MARK: - Additional Response Structures

struct PlaceDetailsResponse: Codable {
    let result: PlaceDetails
    let status: String
}