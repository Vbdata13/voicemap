import Foundation

class PromptManager {
    static let shared = PromptManager()
    private init() {}
    
    private func loadPrompt(filename: String, fallback: String = "") -> String {
        // Try to load from bundle first
        if let path = Bundle.main.path(forResource: filename, ofType: "txt", inDirectory: "Prompts"),
           let content = try? String(contentsOfFile: path) {
            print("✅ Loaded prompt from bundle: \(filename).txt")
            return content
        }
        
        // Try direct file system path as fallback
        let directPath = "/Users/cyberpunkvb/voicemap/VoiceMap/Config/VoiceMap/Prompts/\(filename).txt"
        if let content = try? String(contentsOfFile: directPath) {
            print("✅ Loaded prompt from filesystem: \(filename).txt")
            return content
        }
        
        print("⚠️ Failed to load prompt file: \(filename).txt, using fallback")
        return fallback
    }
    
    // System prompts
    var strategySystemPrompt: String {
        return loadPrompt(filename: "strategy_system_prompt", fallback: """
You are an intelligent location search strategist. You analyze user requests and return JSON strategy plans for optimal data gathering.

ALWAYS respond with valid JSON in the exact formats shown below. Choose the appropriate format based on query complexity:

For SIMPLE location searches: Return basic JSON with needs_places_search, search_query, radius, and response_text.

For COMPLEX or MULTI-STAGE searches: Return enhanced JSON with data_strategy object.

Your JSON response will be parsed by code, so it must be perfectly formatted with no extra text before or after.
""")
    }
    
    var finalResponseSystemPrompt: String {
        return loadPrompt(filename: "final_response_system_prompt", fallback: """
You are a friendly voice assistant that provides natural, conversational responses about places and locations. 

Your response will be read aloud via text-to-speech, so:
- Use natural, conversational language
- Be concise but helpful  
- NEVER include JSON, code, or technical formatting
- Speak in first person ("I found..." not "Here are...")
- Include specific details like names, distances, and ratings when available

Focus on being helpful and natural-sounding for voice interaction.
""")
    }
    
    // Template prompts
    func strategyPrompt(speech: String, latitude: Double, longitude: Double, timestamp: String) -> String {
        let template = loadPrompt(filename: "strategy_prompt_template", fallback: """
You are an intelligent location search strategist. Analyze this user request and determine the optimal data gathering approach.

User request: "{SPEECH}"
Current location: 
- Latitude: {LATITUDE}
- Longitude: {LONGITUDE}
- Time: {TIMESTAMP}

Based on the query complexity, respond with JSON in one of these formats:

For COMPLEX queries requiring review analysis (e.g., "spiciest food", "quietest coffee", "best for families"):
{
  "needs_places_search": true,
  "search_query": "pani puri OR chaat OR indian street food",
  "radius": 5000,
  "response_text": "Let me find the spiciest options for you.",
  "data_strategy": {
    "query_type": "attribute_analysis",
    "complexity": "high",
    "search_terms": ["pani puri", "chaat"],
    "api_calls_needed": ["nearby_search", "place_details", "reviews_analysis"],
    "analysis_required": {
      "type": "keyword_extraction",
      "keywords": ["spicy", "hot", "fire", "burn"],
      "min_reviews": 5,
      "sentiment_focus": "spice_level",
      "review_limit": 15,
      "recent_only": true
    },
    "response_format": "attribute_ranked"
  }
}

For SIMPLE queries (e.g., "Find coffee near me"):
{
  "needs_places_search": true,
  "search_query": "coffee OR cafe OR starbucks OR dunkin OR peets OR blue bottle OR caribou",
  "radius": 3000,
  "response_text": "Looking for coffee shops nearby.",
  "data_strategy": {
    "query_type": "basic_location",
    "complexity": "low",
    "search_terms": ["coffee", "cafe", "starbucks", "dunkin", "peets", "blue bottle", "caribou"],
    "api_calls_needed": ["nearby_search"],
    "response_format": "simple_list"
  }
}

For NON-LOCATION queries:
{
  "needs_places_search": false,
  "response_text": "I'm a location assistant. I can help you find places, restaurants, and businesses near you."
}

Analyze the user's intent and complexity level, then respond with the appropriate JSON format.
""")
        return template
            .replacingOccurrences(of: "{SPEECH}", with: speech)
            .replacingOccurrences(of: "{LATITUDE}", with: String(format: "%.6f", latitude))
            .replacingOccurrences(of: "{LONGITUDE}", with: String(format: "%.6f", longitude))
            .replacingOccurrences(of: "{TIMESTAMP}", with: timestamp)
    }
    
    func finalResponsePrompt(speech: String, latitude: Double, longitude: Double, placesData: String) -> String {
        let template = loadPrompt(filename: "final_response_template", fallback: """
User request: "{SPEECH}"
Location: {LATITUDE}, {LONGITUDE}

REAL PLACES DATA FROM GOOGLE PLACES API:
{PLACES_DATA}

CRITICAL: Only use the places listed above. Do NOT mention any places not in this list. Do NOT make up or guess any business names, addresses, or distances.

Respond naturally about the closest place(s) from the real data above. Use the exact names, distances, and details provided.
""")
        return template
            .replacingOccurrences(of: "{SPEECH}", with: speech)
            .replacingOccurrences(of: "{LATITUDE}", with: String(format: "%.6f", latitude))
            .replacingOccurrences(of: "{LONGITUDE}", with: String(format: "%.6f", longitude))
            .replacingOccurrences(of: "{PLACES_DATA}", with: placesData)
    }
    
    func multiStageResponsePrompt(speech: String, primaryQuery: String, secondaryQuery: String, placesData: String) -> String {
        let template = loadPrompt(filename: "multi_stage_response_template", fallback: """
User request: "{SPEECH}"
This was a multi-stage search: find '{SECONDARY_QUERY}' near '{PRIMARY_QUERY}'

Multi-stage results:
{PLACES_DATA}

Provide a natural response explaining the best options, mentioning both the anchor location and the target business. Keep it conversational and helpful.
""")
        return template
            .replacingOccurrences(of: "{SPEECH}", with: speech)
            .replacingOccurrences(of: "{PRIMARY_QUERY}", with: primaryQuery)
            .replacingOccurrences(of: "{SECONDARY_QUERY}", with: secondaryQuery)
            .replacingOccurrences(of: "{PLACES_DATA}", with: placesData)
    }
}