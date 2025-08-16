import Foundation

// Keep original SearchIntent for backward compatibility
struct SearchIntent: Codable {
    let needsPlacesSearch: Bool
    let searchQuery: String?
    let radius: Int?
    let responseText: String
    
    enum CodingKeys: String, CodingKey {
        case needsPlacesSearch = "needs_places_search"
        case searchQuery = "search_query"
        case radius
        case responseText = "response_text"
    }
}

class AIResponseParser {
    
    // Enhanced parser for complex queries
    static func parseEnhancedSearchIntent(from aiResponse: String) -> EnhancedSearchIntent {
        // Try to parse enhanced JSON response from AI
        if let data = aiResponse.data(using: .utf8),
           let intent = try? JSONDecoder().decode(EnhancedSearchIntent.self, from: data) {
            return intent
        }
        
        // Fallback to basic parsing
        let basicIntent = parseSearchIntent(from: aiResponse)
        
        // Convert to enhanced format
        return EnhancedSearchIntent(
            needsPlacesSearch: basicIntent.needsPlacesSearch,
            searchQuery: basicIntent.searchQuery,
            radius: basicIntent.radius,
            responseText: basicIntent.responseText,
            dataStrategy: nil,
            isMultiStage: false,
            primaryQuery: nil,
            secondaryQuery: nil
        )
    }
    
    // Original parser for backward compatibility
    static func parseSearchIntent(from aiResponse: String) -> SearchIntent {
        // Try to parse JSON response from AI
        if let data = aiResponse.data(using: .utf8),
           let intent = try? JSONDecoder().decode(SearchIntent.self, from: data) {
            return intent
        }
        
        // Fallback: analyze text for search indicators
        let lowercased = aiResponse.lowercased()
        let searchKeywords = ["find", "search", "where", "nearest", "nearby", "looking for", "location of"]
        let needsSearch = searchKeywords.contains { lowercased.contains($0) }
        
        return SearchIntent(
            needsPlacesSearch: needsSearch,
            searchQuery: needsSearch ? extractSearchQuery(from: aiResponse) : nil,
            radius: 3000,
            responseText: aiResponse
        )
    }
    
    private static func extractSearchQuery(from text: String) -> String? {
        // Simple extraction logic - in production, this would be more sophisticated
        let patterns = [
            "find (.+)",
            "search for (.+)",
            "where is (.+)",
            "nearest (.+)",
            "nearby (.+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
}