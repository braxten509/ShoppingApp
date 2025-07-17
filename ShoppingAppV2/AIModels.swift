
import Foundation

struct AIResponse: Codable {
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
    
    struct Usage: Codable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }
}

struct PriceTagInfo: Codable {
    let name: String
    let price: Double
    let taxRate: Double?
    let taxDescription: String?
    let ingredients: String?
}

struct PromptHistoryItem: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: String // "Image Analysis" or "Tax Lookup"
    let prompt: String
    let response: String
    let estimatedCost: Double
    let inputTokens: Int
    let outputTokens: Int
    let itemName: String? // For context
    let aiService: String? // "OpenAI" or "Perplexity"
    let model: String? // "gpt-4o-mini", "llama-3.1-sonar-small-128k-online", etc.
    
    init(timestamp: Date, type: String, prompt: String, response: String, estimatedCost: Double, inputTokens: Int, outputTokens: Int, itemName: String? = nil, aiService: String? = nil, model: String? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.type = type
        self.prompt = prompt
        self.response = response
        self.estimatedCost = estimatedCost
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.itemName = itemName
        self.aiService = aiService
        self.model = model
    }
}
