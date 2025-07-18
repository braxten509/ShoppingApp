
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
        let response = try JSONDecoder().decode(AIResponse.self, from: data)
        return response.choices.first?.message.content ?? ""
    }
    

    func analyzeItemForTax(itemName: String, location: String? = nil, retryCount: Int = 0) async throws -> Double? {
        // Check if manual tax rate is enabled
        if settingsService.useManualTaxRate {
            return settingsService.manualTaxRate
        }
        
        let model = settingsService.selectedModelForTaxRate
        let apiKey = getAPIKey(for: model)
        let url = getAPIURL(for: model)

        let prompt = settingsService.getTaxRatePrompt(itemName: itemName, location: location)
        
        let (data, _) = try await performRequest(prompt: prompt, apiKey: apiKey, url: url, model: model)
        
        print("Raw response from \(model) for tax analysis: \(String(data: data, encoding: .utf8) ?? "No response")")

        let content = try extractContent(from: data, for: model)
        
        let cleanedContent = extractJSON(from: content)
        
        struct TaxResponse: Codable { 
            let taxRate: Double?
            let explanation: String?
        }
        
        var taxResponse: TaxResponse?
        
        // Try to parse JSON first
        if let jsonData = cleanedContent.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(TaxResponse.self, from: jsonData) {
            taxResponse = parsed
        } else {
            // Fallback: try to extract tax rate from text
            print("JSON parsing failed, attempting to extract tax rate from text: \(content)")
            
            // Look for patterns like "6.0%", "6%", "tax rate is 6.0", "taxRate": 6.0, etc.
            let patterns = [
                #"(?:sales tax rate|tax rate|combined.*?rate).*?(?:is )?(\d+(?:\.\d+)?)%"#,
                #"(\d+(?:\.\d+)?)%.*?(?:sales tax|tax rate)"#,
                #"\"?taxRate\"?\s*:\s*(\d+(?:\.\d+)?)"#,
                #"\{[^}]*\"?taxRate\"?[^}]*?(\d+(?:\.\d+)?)[^}]*\}"#,
                #"(\d+(?:\.\d+)?)%"#,
                #"(\d+(?:\.\d+)?)\s*percent"#,
                #"rate.*?(\d+(?:\.\d+)?)"#
            ]
            
            var extractedRate: Double?
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
                   let range = Range(match.range(at: 1), in: content) {
                    let rateString = String(content[range])
                    extractedRate = Double(rateString)
                    print("Extracted tax rate: \(extractedRate ?? 0) from pattern: \(pattern)")
                    break
                }
            }
            
            if let rate = extractedRate {
                taxResponse = TaxResponse(taxRate: rate, explanation: "Extracted from text response")
            } else {
                throw NSError(domain: "APIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract tax rate from response: \(content)"])
            }
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
        
        // If tax rate is nil, try retry logic then throw descriptive error
        if let response = taxResponse, let rate = response.taxRate {
            return rate
        } else {
            // Retry logic - try up to 4 more times with improved prompts
            if retryCount < 4 {
                print("Tax detection failed, retrying (\(retryCount + 1)/4)...")
                try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
                return try await analyzeItemForTax(itemName: itemName, location: location, retryCount: retryCount + 1)
            }
            
            // If all retries failed, throw error so UI can mark as "Unknown tax"
            print("Tax detection failed after \(retryCount + 1) attempts")
            let errorMessage = taxResponse?.explanation ?? "Unable to determine tax rate for '\(itemName)' after \(retryCount + 1) attempts"
            throw NSError(domain: "TaxAnalysisError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: errorMessage
            ])
        }
    }

    func analyzePriceTag(image: UIImage, location: String? = nil) async throws -> PriceTagInfo {
        let model = settingsService.selectedModelForPhotoPrice
        let apiKey = getAPIKey(for: model)
        let url = getAPIURL(for: model)
        
        let prompt = """
        Analyze the image. Respond with ONLY a valid JSON object in the format:
        {"name": "<item_name>", "price": <price>, "taxRate": <tax_rate>, "taxDescription": "<description>", "ingredients": "<ingredients_list>", "analysisIssues": ["<issue1>", "<issue2>"]}
        
        Instructions:
        - name: Extract the exact product name. Use "Unknown Item" only if text is completely unreadable.
        - price: Extract the numerical price. Use 0 only if no price is visible or readable.
        - taxRate: Extract tax rate if visible on tag. Use null if no tax info is present (this is normal - tax rates are rarely shown on price tags).
        - taxDescription: Describe tax source or "Unknown Taxes" if no tax info.
        - ingredients: Extract full ingredients list if visible, or null if not present.
        - analysisIssues: Provide specific explanations for any default values you return:
          * If you return "Unknown Item" for name: explain specifically why (e.g., "Text is too blurry to read", "Product name is cut off in image", "Poor lighting obscures text")
          * If you return 0 for price: explain specifically why (e.g., "Price sticker is peeled off", "Numbers are too small to read clearly", "Price is partially covered")
          * Do NOT mention tax rate issues since tax rates are usually not on price tags anyway
        
        Always provide genuine, specific explanations based on what you actually observe in the image. Empty array only if all values were successfully extracted.
        """

        let (data, _) = try await performRequest(prompt: prompt, apiKey: apiKey, url: url, model: model, image: image)
        
        print("Raw response from \(model) for price tag analysis: \(String(data: data, encoding: .utf8) ?? "No response")")

        let content = try extractContent(from: data, for: model)
        
        let cleanedContent = extractJSON(from: content)

        guard let jsonData = cleanedContent.data(using: .utf8),
              let priceTagInfo = try? JSONDecoder().decode(PriceTagInfo.self, from: jsonData) else {
            throw NSError(domain: "APIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode price tag response"])
        }
        
        // Use AI-provided analysis issues (the AI should explain any default values it returns)
        // No client-side fallback - we want the AI to provide context-specific explanations
        
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
        
        // Automatically search for tax info if:
        // 1. Manual tax rate is not enabled (meaning we should use AI for tax detection)
        // 2. We have a valid item name
        // 3. Tax rate wasn't already found in the image
        var updatedPriceTagInfo = priceTagInfo
        if !settingsService.useManualTaxRate && 
           priceTagInfo.name != "Unknown Item" && 
           !priceTagInfo.name.isEmpty &&
           priceTagInfo.taxRate == nil {
            
            do {
                let detectedTaxRate = try await analyzeItemForTax(itemName: priceTagInfo.name, location: location)
                updatedPriceTagInfo = PriceTagInfo(
                    name: priceTagInfo.name,
                    price: priceTagInfo.price,
                    taxRate: detectedTaxRate,
                    taxDescription: location != nil ? "\(detectedTaxRate ?? 0)% (Auto-detected)" : "\(detectedTaxRate ?? 0)% (Default rate)",
                    ingredients: priceTagInfo.ingredients,
                    analysisIssues: priceTagInfo.analysisIssues
                )
            } catch {
                // If tax lookup fails, keep original info but add note
                var issues = priceTagInfo.analysisIssues ?? []
                issues.append("Tax rate lookup failed: \(error.localizedDescription)")
                updatedPriceTagInfo = PriceTagInfo(
                    name: priceTagInfo.name,
                    price: priceTagInfo.price,
                    taxRate: nil,
                    taxDescription: "Unknown Taxes",
                    ingredients: priceTagInfo.ingredients,
                    analysisIssues: issues
                )
            }
        }
        
        return updatedPriceTagInfo
    }
    
    func searchPrice(itemName: String, specification: String?, website: String, location: String?) async throws -> PriceSearchResult {
        let model = settingsService.selectedModelForTagIdentification
        let apiKey = getAPIKey(for: model)
        let url = getAPIURL(for: model)
        
        // Build the search URL based on selected website
        let searchURL = buildSearchURL(for: website, itemName: itemName, specification: specification)
        let locationContext = location ?? "unknown location"
        
        let prompt = """
        Search for the item "\(itemName)" \(specification != nil ? "with specification: \(specification!)" : "") on \(website) at this URL: \(searchURL)
        
        Current location: \(locationContext)
        
        Instructions:
        1. Go to the URL and search for products matching "\(itemName)" \(specification != nil ? "with specification \(specification!)" : "")
        2. If you find similar items, return:
           - found: true
           - itemName: exact product name from website
           - price: price as number only (no $ symbol)
           - description: brief product description (1-2 sentences)
           - sourceURL: the specific product page URL
        3. If NO similar items are found, return:
           - found: false
           - itemName: ""
           - price: null
           - description: ""
           - sourceURL: null
        
        Return response as JSON in this exact format:
        {
            "found": boolean,
            "itemName": "string",
            "price": number or null,
            "description": "string",
            "sourceURL": "string or null"
        }
        """
        
        let (data, _) = try await performRequest(prompt: prompt, apiKey: apiKey, url: url, model: model)
        
        do {
            let result = try JSONDecoder().decode(PriceSearchResult.self, from: data)
            return result
        } catch {
            // If JSON parsing fails, return not found
            return PriceSearchResult(found: false, description: "Unable to parse search results")
        }
    }
    
    private func buildSearchURL(for website: String, itemName: String, specification: String?) -> String {
        let searchTerm = specification != nil ? "\(itemName) \(specification!)" : itemName
        return settingsService.buildSearchURL(for: website, searchTerm: searchTerm) ?? ""
    }
    
    func guessPrice(itemName: String, location: String?, storeName: String? = nil, brand: String? = nil, additionalDetails: String?) async throws -> (price: Double?, sourceURL: String?) {
        let model = settingsService.selectedModelForTagIdentification
        let apiKey = getAPIKey(for: model)
        let url = getAPIURL(for: model)

        let prompt = """
        Find the price of "\(itemName)" \(brand != nil ? "brand: \(brand!)" : "") \(additionalDetails != nil ? "details: \(additionalDetails!)" : "") at \(storeName ?? "a major retailer").
        Respond with ONLY a valid JSON object in the format {"estimatedPrice": <price>, "sourceURL": "<url>", "explanation": "<explanation>"}.
        If no price is found, return {"estimatedPrice": null, "sourceURL": null, "explanation": "<specific reason>"}.
        """

        let (data, _) = try await performRequest(prompt: prompt, apiKey: apiKey, url: url, model: model)
        
        print("Raw response from \(model) for price guess: \(String(data: data, encoding: .utf8) ?? "No response")")

        let content = try extractContent(from: data, for: model)
        
        let cleanedContent = extractJSON(from: content)
        
        struct PriceResponse: Codable {
            let estimatedPrice: Double?
            let sourceURL: String?
            let explanation: String?
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
        
        // If price is nil, throw a descriptive error using AI's explanation
        if priceResponse.estimatedPrice == nil {
            let errorMessage = priceResponse.explanation ?? "Unable to find current pricing for '\(itemName)'"
            throw NSError(domain: "PriceGuessError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: errorMessage
            ])
        }
        
        return (priceResponse.estimatedPrice, priceResponse.sourceURL)
    }

    func analyzeProductForAdditives(productName: String) async throws -> (risky: Int, safe: Int, additiveDetails: [AdditiveInfo])? {
        let model = settingsService.selectedModelForTagIdentification
        let apiKey = getAPIKey(for: model)
        let url = getAPIURL(for: model)

        let prompt = """
        Analyze the additives in "\(productName)".
        Respond with ONLY a valid JSON object in the format:
        {"riskyAdditives": [{"name": "<name>", "riskLevel": "<level>", "description": "<desc>"}], "safeAdditives": [{"name": "<name>", "description": "<desc>"}], "explanation": "<explanation>"}
        If ingredients are unknown, return {"riskyAdditives": null, "safeAdditives": null, "explanation": "<specific reason>"}.
        """

        let (data, _) = try await performRequest(prompt: prompt, apiKey: apiKey, url: url, model: model)
        
        print("Raw response from \(model) for additive analysis: \(String(data: data, encoding: .utf8) ?? "No response")")

        let content = try extractContent(from: data, for: model)
        
        let cleanedContent = extractJSON(from: content)
        
        struct AdditivesResponse: Codable {
            let riskyAdditives: [AdditiveInfo]?
            let safeAdditives: [AdditiveInfo]?
            let explanation: String?
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
        
        // If both risky and safe additives are nil, throw a descriptive error using AI's explanation
        if additivesResponse.riskyAdditives == nil && additivesResponse.safeAdditives == nil {
            let errorMessage = additivesResponse.explanation ?? "Unable to analyze additives for '\(productName)'"
            throw NSError(domain: "AdditiveAnalysisError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: errorMessage
            ])
        }
        
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
        case "gpt-4o-mini":
            return settingsService.openAIAPIKey
        case "sonar-pro", "sonar":
            return settingsService.perplexityAPIKey
        default:
            return ""
        }
    }

    private func supportsImages(model: String) -> Bool {
        // All models in our supported list have vision capabilities
        switch model {
        case "gpt-4o-mini", "sonar-pro", "sonar":
            return true
        default:
            return false
        }
    }
    
    private func getAPIURL(for model: String) -> URL {
        switch model {
        case "sonar-pro", "sonar":
            return URL(string: "https://api.perplexity.ai/chat/completions")!
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
        default:
            return "Unknown"
        }
    }
    
}
