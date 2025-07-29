
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

    private func extractContent(from data: Data, for model: String) throws -> (content: String, usage: AIResponse.Usage?) {
        let response = try JSONDecoder().decode(AIResponse.self, from: data)
        let content = response.choices.first?.message.content ?? ""
        return (content, response.usage)
    }
    
    private func estimateTokens(_ text: String) -> Int {
        // Improved token estimation based on OpenAI's cl100k_base tokenizer patterns
        let characterCount = text.count
        let baseEstimate = max(1, characterCount / 4)
        
        var tokenCount = baseEstimate
        
        // Add overhead for JSON structure
        if text.contains("{") || text.contains("[") {
            tokenCount = Int(Double(tokenCount) * 1.15)
        }
        
        // Add overhead for complex punctuation and special characters
        let specialCharCount = text.filter { ".,!?;:()[]{}\"'`-_=+*/\\|@#$%^&<>".contains($0) }.count
        if specialCharCount > characterCount / 20 {
            tokenCount = Int(Double(tokenCount) * 1.1)
        }
        
        // Add overhead for newlines and formatting
        let newlineCount = text.filter { $0.isNewline }.count
        if newlineCount > 5 {
            tokenCount += newlineCount / 2
        }
        
        // Conservative multiplier
        tokenCount = Int(Double(tokenCount) * 1.2)
        
        return max(1, tokenCount)
    }
    

    func analyzeItemForTax(itemName: String, location: String? = nil, retryCount: Int = 0, progressCallback: ((Int, Int) -> Void)? = nil) async throws -> Double? {
        // Check if manual tax rate is enabled
        if settingsService.useManualTaxRate {
            return settingsService.manualTaxRate
        }
        
        // Check if multi-attempt detection is enabled
        if settingsService.useMultiAttemptTaxDetection && retryCount == 0 {
            return try await performMultiAttemptTaxDetection(itemName: itemName, location: location, progressCallback: progressCallback)
        }
        
        let model = settingsService.selectedModelForTaxRate
        let apiKey = getAPIKey(for: model)
        let url = getAPIURL(for: model)

        let prompt = settingsService.getTaxRatePrompt(itemName: itemName, location: location)
        
        let (data, _) = try await performRequest(prompt: prompt, apiKey: apiKey, url: url, model: model, includeSearchOptions: true)
        
        print("Raw response from \(model) for tax analysis: \(String(data: data, encoding: .utf8) ?? "No response")")

        let (content, usage) = try extractContent(from: data, for: model)
        
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
            
            // Look specifically for the XX3.00XX format as requested by the user
            let patterns = [
                #"XX(\d+(?:\.\d+)?)XX"#  // Matches XX3.00XX format and extracts the number
            ]
            
            var extractedRate: Double?
            for pattern in patterns {
                print("Trying pattern: \(pattern) on content: '\(content)'")
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
                   let range = Range(match.range(at: 1), in: content) {
                    let rateString = String(content[range])
                    extractedRate = Double(rateString)
                    print("✅ Extracted tax rate: \(extractedRate ?? 0) from pattern: \(pattern)")
                    break
                } else {
                    print("❌ Pattern failed: \(pattern)")
                }
            }
            
            if let rate = extractedRate {
                taxResponse = TaxResponse(taxRate: rate, explanation: "Extracted from text response")
            } else {
                throw NSError(domain: "APIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract tax rate from response: \(content)"])
            }
        }
        
        // Calculate accurate cost based on actual or estimated token usage
        let inputTokens = usage?.prompt_tokens ?? estimateTokens(prompt)
        let outputTokens = usage?.completion_tokens ?? estimateTokens(content)
        let actualCost = PricingService.shared.calculateCost(for: model, inputTokens: inputTokens, outputTokens: outputTokens)
        
        // Debug logging for token usage accuracy
        if let actualUsage = usage {
            print("Tax analysis - Actual tokens: input=\(actualUsage.prompt_tokens), output=\(actualUsage.completion_tokens)")
            let estimatedInput = estimateTokens(prompt)
            let estimatedOutput = estimateTokens(content)
            print("Tax analysis - Estimated tokens: input=\(estimatedInput), output=\(estimatedOutput)")
            print("Tax analysis - Estimation accuracy: input=\(Int((Double(estimatedInput)/Double(actualUsage.prompt_tokens))*100))%, output=\(Int((Double(estimatedOutput)/Double(actualUsage.completion_tokens))*100))%")
        }
        
        // Track this interaction with billing and history
        historyService.add(item: PromptHistoryItem(
            timestamp: Date(),
            type: "Tax Lookup",
            prompt: prompt,
            response: content,
            estimatedCost: actualCost,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            itemName: itemName,
            aiService: getServiceName(for: model),
            model: model
        ))
        billingService.addCost(amount: actualCost)
        
        // Deduct from credits if we have a sync date
        if let _ = settingsService.lastSyncDate {
            if model.hasPrefix("gpt-") {
                settingsService.deductOpenAICredits(actualCost)
            } else if model.hasPrefix("sonar") {
                settingsService.deductPerplexityCredits(actualCost)
            }
        }
        
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
    
    private func performMultiAttemptTaxDetection(itemName: String, location: String?, progressCallback: ((Int, Int) -> Void)?) async throws -> Double? {
        let totalAttempts = settingsService.taxDetectionAttempts
        var responses: [Double] = []
        
        print("🔄 Starting multi-attempt tax detection for '\(itemName)' with \(totalAttempts) attempts")
        
        for attempt in 1...totalAttempts {
            progressCallback?(attempt, totalAttempts)
            
            do {
                // Call the single attempt method with retryCount > 0 to avoid infinite recursion
                let taxRate = try await analyzeItemForTax(itemName: itemName, location: location, retryCount: 1)
                if let rate = taxRate {
                    responses.append(rate)
                    print("📊 Tax attempt \(attempt)/\(totalAttempts): \(String(format: "%.2f%%", rate))")
                } else {
                    print("❌ Tax attempt \(attempt)/\(totalAttempts): No rate returned")
                }
            } catch {
                print("❌ Tax attempt \(attempt)/\(totalAttempts) failed: \(error)")
            }
        }
        
        // Find the most common response
        if responses.isEmpty {
            throw NSError(domain: "TaxAnalysisError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "All \(totalAttempts) tax detection attempts failed for '\(itemName)'"
            ])
        }
        
        let responseCounts = Dictionary(grouping: responses, by: { $0 }).mapValues { $0.count }
        let mostCommon = responseCounts.max(by: { $0.value < $1.value })
        let mostCommonRate = mostCommon?.key ?? responses.first!
        let occurrences = mostCommon?.value ?? 1
        
        print("✅ Multi-attempt tax detection complete: \(String(format: "%.2f%%", mostCommonRate)) appeared \(occurrences)/\(responses.count) times")
        
        return mostCommonRate
    }

    func analyzePriceTag(image: UIImage, location: String? = nil) async throws -> PriceTagInfo {
        let model = settingsService.selectedModelForPhotoPrice
        let apiKey = getAPIKey(for: model)
        let url = getAPIURL(for: model)
        
        let prompt = """
        Analyze the image and extract ONLY the product name and price. Respond with a valid JSON object:
        {"name": "<item_name>", "price": <price>}
        
        Instructions:
        - name: Extract the exact product name. Use "Unknown Item" only if text is completely unreadable.
        - price: Extract the numerical price (number only, no $ symbol). Use 0 if no price is visible.
        
        Keep the response minimal - only name and price, nothing else.
        """

        let (data, _) = try await performRequest(prompt: prompt, apiKey: apiKey, url: url, model: model, image: image)
        
        print("Raw response from \(model) for price tag analysis: \(String(data: data, encoding: .utf8) ?? "No response")")

        let (content, usage) = try extractContent(from: data, for: model)
        
        let cleanedContent = extractJSON(from: content)

        // Parse simplified response
        struct SimpleResponse: Codable {
            let name: String
            let price: Double
        }
        
        guard let jsonData = cleanedContent.data(using: .utf8),
              let simpleResponse = try? JSONDecoder().decode(SimpleResponse.self, from: jsonData) else {
            throw NSError(domain: "APIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode price tag response"])
        }
        
        // Convert to PriceTagInfo with default values for unused fields
        let priceTagInfo = PriceTagInfo(
            name: simpleResponse.name,
            price: simpleResponse.price,
            taxRate: nil,
            taxDescription: "Unknown Taxes",
            ingredients: nil,
            analysisIssues: nil
        )
        
        // Use AI-provided analysis issues (the AI should explain any default values it returns)
        // No client-side fallback - we want the AI to provide context-specific explanations
        
        // Calculate accurate cost based on actual or estimated token usage
        // For image analysis, add estimated image tokens if usage not provided
        let baseInputTokens = usage?.prompt_tokens ?? estimateTokens(prompt)
        let inputTokens = usage?.prompt_tokens ?? (baseInputTokens + 765) // Add ~765 tokens for image if no usage data
        let outputTokens = usage?.completion_tokens ?? estimateTokens(content)
        let actualCost = PricingService.shared.calculateCost(for: model, inputTokens: inputTokens, outputTokens: outputTokens)
        
        // Debug logging for token usage accuracy
        if let actualUsage = usage {
            print("Image analysis - Actual tokens: input=\(actualUsage.prompt_tokens), output=\(actualUsage.completion_tokens)")
            let estimatedInput = estimateTokens(prompt) + 765 // Add image tokens to estimation
            let estimatedOutput = estimateTokens(content)
            print("Image analysis - Estimated tokens: input=\(estimatedInput), output=\(estimatedOutput)")
        } else {
            print("Image analysis - No usage data returned, using estimates with image tokens")
        }
        
        // Track this interaction with billing and history
        historyService.add(item: PromptHistoryItem(
            timestamp: Date(),
            type: "Image Analysis",
            prompt: prompt,
            response: content,
            estimatedCost: actualCost,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            itemName: priceTagInfo.name,
            aiService: getServiceName(for: model),
            model: model
        ))
        billingService.addCost(amount: actualCost)
        
        // Deduct from credits if we have a sync date
        if let _ = settingsService.lastSyncDate {
            if model.hasPrefix("gpt-") {
                settingsService.deductOpenAICredits(actualCost)
            } else if model.hasPrefix("sonar") {
                settingsService.deductPerplexityCredits(actualCost)
            }
        }
        
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
    


    private func performRequest(prompt: String, apiKey: String, url: URL, model: String, image: UIImage? = nil, includeSearchOptions: Bool = false) async throws -> (Data, URLResponse) {
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
                
                // Add web search options for Perplexity models
                if includeSearchOptions && (model.hasPrefix("sonar")) {
                    var webSearchOptions: [String: Any] = [
                        "search_context_size": settingsService.taxSearchContextSize
                    ]
                    
                    if let recencyFilter = settingsService.taxSearchRecencyFilter, !recencyFilter.isEmpty {
                        webSearchOptions["search_recency_filter"] = recencyFilter
                    }
                    
                    payload["web_search_options"] = webSearchOptions
                    print("🔍 Added web search options: \(webSearchOptions)")
                }
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
