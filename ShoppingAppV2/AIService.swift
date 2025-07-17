
import Foundation
import UIKit

class AIService: ObservableObject {
    private let settingsService: SettingsService
    private let billingService: BillingService
    private let historyService: HistoryService

    init(settingsService: SettingsService, billingService: BillingService, historyService: HistoryService) {
        self.settingsService = settingsService
        self.billingService = billingService
        self.historyService = historyService
    }

    private func extractContent(from data: Data, for model: String) throws -> String {
        if model.contains("Gemini") {
            let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
            return response.candidates.first?.content.parts.first?.text ?? ""
        } else {
            let response = try JSONDecoder().decode(AIResponse.self, from: data)
            return response.choices.first?.message.content ?? ""
        }
    }
    
    private func buildPrompt(for type: PromptType, replacements: [String: String]) -> String {
        var prompt = settingsService.getPrompt(for: type)
        
        for (placeholder, value) in replacements {
            prompt = prompt.replacingOccurrences(of: "{\(placeholder)}", with: value)
        }
        
        return prompt
    }

    func analyzeItemForTax(itemName: String, location: String? = nil) async throws -> Double? {
        let model = settingsService.selectedModelForTaxRate
        let apiKey = getAPIKey(for: model)
        let url = getAPIURL(for: model)

        let locationContext = location != nil ? "The user is in \(location!)." : "No location provided."
        let prompt = buildPrompt(for: .taxRate, replacements: [
            "itemName": itemName,
            "locationContext": locationContext
        ])
        
        let (data, _) = try await performRequest(prompt: prompt, apiKey: apiKey, url: url, model: model)
        
        print("Raw response from \(model) for tax analysis: \(String(data: data, encoding: .utf8) ?? "No response")")

        let content = try extractContent(from: data, for: model)
        
        let cleanedContent = extractJSON(from: content)
        
        struct TaxResponse: Codable { let taxRate: Double? }
        
        guard let jsonData = cleanedContent.data(using: .utf8),
              let taxResponse = try? JSONDecoder().decode(TaxResponse.self, from: jsonData) else {
            throw NSError(domain: "APIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode tax response"])
        }
        
        // Track this interaction with billing and history
        historyService.add(item: PromptHistoryItem(
            timestamp: Date(),
            type: "Tax Lookup",
            prompt: prompt,
            response: content,
            estimatedCost: 0.001, // Estimated cost for tax lookup
            inputTokens: prompt.count / 4, // Rough token estimate
            outputTokens: content.count / 4,
            itemName: itemName,
            aiService: getServiceName(for: model),
            model: model
        ))
        billingService.addCost(amount: 0.001)
        
        return taxResponse.taxRate
    }

    func analyzePriceTag(image: UIImage, location: String? = nil) async throws -> PriceTagInfo {
        let model = settingsService.selectedModelForPhotoPrice
        let apiKey = getAPIKey(for: model)
        let url = getAPIURL(for: model)
        
        let locationContext = location != nil ? "The user is in \(location!)." : "No location provided."
        let prompt = buildPrompt(for: .priceTagAnalysis, replacements: [
            "locationContext": locationContext
        ])

        let (data, _) = try await performRequest(prompt: prompt, apiKey: apiKey, url: url, model: model, image: image)
        
        print("Raw response from \(model) for price tag analysis: \(String(data: data, encoding: .utf8) ?? "No response")")

        let content = try extractContent(from: data, for: model)
        
        let cleanedContent = extractJSON(from: content)

        guard let jsonData = cleanedContent.data(using: .utf8),
              let priceTagInfo = try? JSONDecoder().decode(PriceTagInfo.self, from: jsonData) else {
            throw NSError(domain: "APIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode price tag response"])
        }
        
        // Track this interaction with billing and history
        historyService.add(item: PromptHistoryItem(
            timestamp: Date(),
            type: "Image Analysis",
            prompt: prompt,
            response: content,
            estimatedCost: 0.005, // Estimated cost for image analysis
            inputTokens: prompt.count / 4,
            outputTokens: content.count / 4,
            itemName: priceTagInfo.name,
            aiService: getServiceName(for: model),
            model: model
        ))
        billingService.addCost(amount: 0.005)
        
        return priceTagInfo
    }
    
    func guessPrice(itemName: String, location: String?, storeName: String? = nil, brand: String? = nil, additionalDetails: String?) async throws -> (price: Double?, sourceURL: String?) {
        let model = settingsService.selectedModelForTagIdentification
        let apiKey = getAPIKey(for: model)
        let url = getAPIURL(for: model)

        let prompt = buildPrompt(for: .priceGuessing, replacements: [
            "itemName": itemName,
            "brand": brand ?? "",
            "additionalDetails": additionalDetails ?? "",
            "storeName": storeName ?? "a major retailer"
        ])

        let (data, _) = try await performRequest(prompt: prompt, apiKey: apiKey, url: url, model: model)
        
        print("Raw response from \(model) for price guess: \(String(data: data, encoding: .utf8) ?? "No response")")

        let content = try extractContent(from: data, for: model)
        
        let cleanedContent = extractJSON(from: content)
        
        struct PriceResponse: Codable {
            let estimatedPrice: Double?
            let sourceURL: String?
        }
        
        guard let jsonData = cleanedContent.data(using: .utf8),
              let priceResponse = try? JSONDecoder().decode(PriceResponse.self, from: jsonData) else {
            throw NSError(domain: "APIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode price response"])
        }
        
        // Track this interaction with billing and history
        historyService.add(item: PromptHistoryItem(
            timestamp: Date(),
            type: "Price Guess",
            prompt: prompt,
            response: content,
            estimatedCost: 0.002,
            inputTokens: prompt.count / 4,
            outputTokens: content.count / 4,
            itemName: itemName,
            aiService: getServiceName(for: model),
            model: model
        ))
        billingService.addCost(amount: 0.002)
        
        return (priceResponse.estimatedPrice, priceResponse.sourceURL)
    }

    func analyzeProductForAdditives(productName: String) async throws -> (risky: Int, safe: Int, additiveDetails: [AdditiveInfo])? {
        let model = settingsService.selectedModelForTagIdentification
        let apiKey = getAPIKey(for: model)
        let url = getAPIURL(for: model)

        let prompt = buildPrompt(for: .additiveAnalysis, replacements: [
            "productName": productName
        ])

        let (data, _) = try await performRequest(prompt: prompt, apiKey: apiKey, url: url, model: model)
        
        print("Raw response from \(model) for additive analysis: \(String(data: data, encoding: .utf8) ?? "No response")")

        let content = try extractContent(from: data, for: model)
        
        let cleanedContent = extractJSON(from: content)
        
        struct AdditivesResponse: Codable {
            let riskyAdditives: [AdditiveInfo]?
            let safeAdditives: [AdditiveInfo]?
        }
        
        guard let jsonData = cleanedContent.data(using: .utf8),
              let additivesResponse = try? JSONDecoder().decode(AdditivesResponse.self, from: jsonData) else {
            throw NSError(domain: "APIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode additives response"])
        }
        
        // Track this interaction with billing and history
        historyService.add(item: PromptHistoryItem(
            timestamp: Date(),
            type: "Additive Analysis",
            prompt: prompt,
            response: content,
            estimatedCost: 0.001,
            inputTokens: prompt.count / 4,
            outputTokens: content.count / 4,
            itemName: productName,
            aiService: getServiceName(for: model),
            model: model
        ))
        billingService.addCost(amount: 0.001)
        
        return (additivesResponse.riskyAdditives?.count ?? 0, additivesResponse.safeAdditives?.count ?? 0, (additivesResponse.riskyAdditives ?? []) + (additivesResponse.safeAdditives ?? []))
    }

    private func performRequest(prompt: String, apiKey: String, url: URL, model: String, image: UIImage? = nil) async throws -> (Data, URLResponse) {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "APIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key not configured for \(model)."])
        }
        
        if let _ = image, !supportsImages(model: model) {
            throw NSError(domain: "APIError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Model \(model) does not support image input."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [:]

        if let image = image, let imageData = image.jpegData(compressionQuality: 0.8) {
            let base64Image = imageData.base64EncodedString()
            
            switch model {
            case "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash-001":
                request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
                payload = [
                    "contents": [
                        "parts": [
                            ["text": prompt],
                            ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]]
                        ]
                    ]
                ]
            default: // OpenAI and Perplexity
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                let modelName = model
                payload = [
                    "model": modelName,
                    "messages": [
                        [
                            "role": "user",
                            "content": [
                                ["type": "text", "text": prompt],
                                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                            ]
                        ]
                    ],
                    "max_tokens": 300
                ]
            }
        } else {
            switch model {
            case "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash-001":
                request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
                payload = [
                    "contents": [
                        "parts": [
                            ["text": prompt]
                        ]
                    ]
                ]
            default: // OpenAI and Perplexity
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                let modelName = model
                payload = [
                    "model": modelName,
                    "messages": [
                        [
                            "role": "user",
                            "content": prompt
                        ]
                    ],
                    "max_tokens": 300
                ]
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        return try await URLSession.shared.data(for: request)
    }

    private func getAPIKey(for model: String) -> String {
        switch model {
        case "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano", "gpt-4o", "gpt-4o-mini":
            return settingsService.openAIAPIKey
        case "sonar-pro", "sonar", "sonar-reasoning-pro":
            return settingsService.perplexityAPIKey
        case "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash-001":
            return settingsService.geminiAPIKey
        default:
            return ""
        }
    }

    private func supportsImages(model: String) -> Bool {
        // All models in our supported list have vision capabilities
        switch model {
        case "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano", "gpt-4o", "gpt-4o-mini", 
             "sonar-pro", "sonar", "sonar-reasoning-pro",
             "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash-001":
            return true
        default:
            return false
        }
    }
    
    private func getAPIURL(for model: String) -> URL {
        switch model {
        case "sonar-pro", "sonar", "sonar-reasoning-pro":
            return URL(string: "https://api.perplexity.ai/chat/completions")!
        case "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash-001":
            return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        default:
            return URL(string: "https://api.openai.com/v1/chat/completions")!
        }
    }
    
    private func extractJSON(from content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let jsonStart = trimmed.range(of: "```json"),
           let jsonEnd = trimmed.range(of: "```", range: jsonStart.upperBound..<trimmed.endIndex) {
            let jsonContent = String(trimmed[jsonStart.upperBound..<jsonEnd.lowerBound])
            return jsonContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard let startIndex = trimmed.firstIndex(of: "{"),
              let endIndex = trimmed.lastIndex(of: "}") else {
            return trimmed
        }
        
        let jsonPart = String(trimmed[startIndex...endIndex])
        return jsonPart.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getServiceName(for model: String) -> String {
        switch model {
        case let m where m.hasPrefix("gpt-"):
            return "OpenAI"
        case let m where m.hasPrefix("sonar"):
            return "Perplexity"
        case let m where m.hasPrefix("gemini"):
            return "Google"
        default:
            return "Unknown"
        }
    }
}
