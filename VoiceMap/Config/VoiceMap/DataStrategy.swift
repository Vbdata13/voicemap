import Foundation
import CoreLocation

// MARK: - Data Strategy Planning Structures

struct DataStrategy: Codable {
    let queryType: QueryType
    let complexity: QueryComplexity
    let searchTerms: [String]
    let apiCallsNeeded: [APICallType]
    let analysisRequired: AnalysisConfig?
    let responseFormat: ResponseFormat
    
    enum CodingKeys: String, CodingKey {
        case queryType = "query_type"
        case complexity
        case searchTerms = "search_terms"
        case apiCallsNeeded = "api_calls_needed"
        case analysisRequired = "analysis_required"
        case responseFormat = "response_format"
    }
}

enum QueryType: String, Codable {
    case basicLocation = "basic_location"
    case preferenceSearch = "preference_search"
    case attributeAnalysis = "attribute_analysis"
    case comparativeSearch = "comparative_search"
    case multiStageSearch = "multi_stage_search"
}

enum QueryComplexity: String, Codable {
    case low, medium, high, veryHigh = "very_high"
}

enum APICallType: String, Codable {
    case nearbySearch = "nearby_search"
    case placeDetails = "place_details"
    case reviewsAnalysis = "reviews_analysis"
    case photosAnalysis = "photos_analysis"
}

enum ResponseFormat: String, Codable {
    case simpleList = "simple_list"
    case rankedResults = "ranked_results"
    case attributeRanked = "attribute_ranked"
    case comparative = "comparative"
    case detailed = "detailed"
}

struct AnalysisConfig: Codable {
    let type: AnalysisType
    let keywords: [String]
    let minReviews: Int?
    let sentimentFocus: String?
    let reviewLimit: Int?
    let recentOnly: Bool?
    
    enum CodingKeys: String, CodingKey {
        case type
        case keywords
        case minReviews = "min_reviews"
        case sentimentFocus = "sentiment_focus"
        case reviewLimit = "review_limit"
        case recentOnly = "recent_only"
    }
}

enum AnalysisType: String, Codable {
    case keywordExtraction = "keyword_extraction"
    case sentimentAnalysis = "sentiment_analysis"
    case attributeScoring = "attribute_scoring"
    case comparativeAnalysis = "comparative_analysis"
}

// MARK: - Enhanced Search Intent

struct EnhancedSearchIntent: Codable {
    let needsPlacesSearch: Bool
    let searchQuery: String?
    let radius: Int?
    let responseText: String
    let dataStrategy: DataStrategy?
    let isMultiStage: Bool?
    let primaryQuery: String?
    let secondaryQuery: String?
    
    enum CodingKeys: String, CodingKey {
        case needsPlacesSearch = "needs_places_search"
        case searchQuery = "search_query"
        case radius
        case responseText = "response_text"
        case dataStrategy = "data_strategy"
        case isMultiStage = "is_multi_stage"
        case primaryQuery = "primary_query"
        case secondaryQuery = "secondary_query"
    }
}

// MARK: - Review Analysis Results

struct ReviewAnalysis: Codable {
    let placeId: String
    let keywordMatches: Int
    let sentimentScore: Double
    let confidenceScore: Double
    let relevantReviews: [String]
    let attributeScore: Double?
    let evidence: [String]
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case keywordMatches = "keyword_matches"
        case sentimentScore = "sentiment_score"
        case confidenceScore = "confidence_score"
        case relevantReviews = "relevant_reviews"
        case attributeScore = "attribute_score"
        case evidence
    }
}

// MARK: - Enhanced Place Result

struct EnhancedPlaceResult: Codable {
    let basicPlace: PlaceResult
    let reviewAnalysis: ReviewAnalysis?
    let attributeScores: [String: Double]?
    let confidenceScore: Double
    let ranking: Int?
    
    enum CodingKeys: String, CodingKey {
        case basicPlace = "basic_place"
        case reviewAnalysis = "review_analysis"
        case attributeScores = "attribute_scores"
        case confidenceScore = "confidence_score"
        case ranking
    }
}

// MARK: - Place Details Structure

struct PlaceDetails: Codable {
    let placeId: String
    let name: String
    let rating: Double?
    let reviews: [PlaceReview]
    let photos: [String]?
    let phoneNumber: String?
    let website: String?
    let openingHours: OpeningHours?
    let priceLevel: Int?
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name
        case rating
        case reviews
        case photos
        case phoneNumber = "formatted_phone_number"
        case website
        case openingHours = "opening_hours"
        case priceLevel = "price_level"
    }
}

struct PlaceReview: Codable {
    let authorName: String
    let rating: Int
    let text: String
    let time: Int
    let relativeTime: String
    
    enum CodingKeys: String, CodingKey {
        case authorName = "author_name"
        case rating
        case text
        case time
        case relativeTime = "relative_time_description"
    }
}

struct OpeningHours: Codable {
    let openNow: Bool
    let weekdayText: [String]
    
    enum CodingKeys: String, CodingKey {
        case openNow = "open_now"
        case weekdayText = "weekday_text"
    }
}