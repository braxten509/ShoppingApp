import Foundation
import UIKit

struct OpenAIResponse: Codable {
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
    
    init(timestamp: Date, type: String, prompt: String, response: String, estimatedCost: Double, inputTokens: Int, outputTokens: Int, itemName: String? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.type = type
        self.prompt = prompt
        self.response = response
        self.estimatedCost = estimatedCost
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.itemName = itemName
    }
}

class OpenAIService: ObservableObject {
    private let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let billingURL = "https://api.openai.com/v1/dashboard/billing/credit_grants"
    
    @Published var promptHistory: [PromptHistoryItem] = []
    @Published var totalSpentAllTime: Double = 0.0
    @Published var totalPromptCount: Int = 0
    @Published var totalImageAnalysisCount: Int = 0
    @Published var totalTaxLookupCount: Int = 0
    @Published var totalImageAnalysisCost: Double = 0.0
    @Published var totalTaxLookupCost: Double = 0.0
    
    private let historyKey = "prompt_history"
    private let initialCreditsKey = "initial_api_credits"
    private let manualSpentKey = "manual_spent_credits"
    private let totalSpentKey = "total_spent_all_time"
    private let totalCountKey = "total_prompt_count"
    private let totalImageAnalysisCountKey = "total_image_analysis_count"
    private let totalTaxLookupCountKey = "total_tax_lookup_count"
    private let totalImageAnalysisCostKey = "total_image_analysis_cost"
    private let totalTaxLookupCostKey = "total_tax_lookup_cost"
    
    init() {
        // Load initial values from UserDefaults
        self.initialCredits = UserDefaults.standard.object(forKey: initialCreditsKey) as? Double ?? 0.0
        self.manualSpentAdjustment = UserDefaults.standard.object(forKey: manualSpentKey) as? Double ?? 0.0
        self.totalSpentAllTime = UserDefaults.standard.object(forKey: totalSpentKey) as? Double ?? 0.0
        self.totalPromptCount = UserDefaults.standard.object(forKey: totalCountKey) as? Int ?? 0
        self.totalImageAnalysisCount = UserDefaults.standard.object(forKey: totalImageAnalysisCountKey) as? Int ?? 0
        self.totalTaxLookupCount = UserDefaults.standard.object(forKey: totalTaxLookupCountKey) as? Int ?? 0
        self.totalImageAnalysisCost = UserDefaults.standard.object(forKey: totalImageAnalysisCostKey) as? Double ?? 0.0
        self.totalTaxLookupCost = UserDefaults.standard.object(forKey: totalTaxLookupCostKey) as? Double ?? 0.0
        loadPromptHistory()
        
        // One-time migration: if totalSpentAllTime is 0 but we have prompt history, migrate
        if totalSpentAllTime == 0.0 && !promptHistory.isEmpty {
            let historicalTotal = promptHistory.reduce(0) { $0 + $1.estimatedCost }
            totalSpentAllTime = historicalTotal
            UserDefaults.standard.set(totalSpentAllTime, forKey: totalSpentKey)
        }
        
        // One-time migration: if totalPromptCount is 0 but we have prompt history, migrate
        if totalPromptCount == 0 && !promptHistory.isEmpty {
            totalPromptCount = promptHistory.count
            UserDefaults.standard.set(totalPromptCount, forKey: totalCountKey)
        }
        
        // One-time migration: if type-specific counts are 0 but we have prompt history, migrate
        if totalImageAnalysisCount == 0 && totalTaxLookupCount == 0 && !promptHistory.isEmpty {
            let imageItems = promptHistory.filter { $0.type == "Image Analysis" }
            let taxItems = promptHistory.filter { $0.type == "Tax Lookup" }
            
            totalImageAnalysisCount = imageItems.count
            totalTaxLookupCount = taxItems.count
            totalImageAnalysisCost = imageItems.reduce(0) { $0 + $1.estimatedCost }
            totalTaxLookupCost = taxItems.reduce(0) { $0 + $1.estimatedCost }
            
            UserDefaults.standard.set(totalImageAnalysisCount, forKey: totalImageAnalysisCountKey)
            UserDefaults.standard.set(totalTaxLookupCount, forKey: totalTaxLookupCountKey)
            UserDefaults.standard.set(totalImageAnalysisCost, forKey: totalImageAnalysisCostKey)
            UserDefaults.standard.set(totalTaxLookupCost, forKey: totalTaxLookupCostKey)
        }
        
        // Validate API key is loaded
        if apiKey.isEmpty {
            print("⚠️ WARNING: OpenAI API key not found. Please set OPENAI_API_KEY in your scheme's environment variables.")
        } else {
            print("✅ OpenAI API key loaded successfully")
        }
    }
    
    func analyzeItemForTax(itemName: String, location: String? = nil) async throws -> Double? {
        let locationContext = location != nil ? " The user is located in \(location!). Look up the correct sales tax rate for this specific location." : " No location provided."
        
        let prompt = """
        Based on the item name "\(itemName)" and location information, determine the appropriate sales tax rate.
        
        \(locationContext)
        
        IMPORTANT: If the item name is ambiguous, unclear, generic (like "test", "123", "item", "thing"), or doesn't represent a real product, return null for the tax rate.
        
        Only provide a tax rate if the item name clearly represents a real, identifiable product that would be subject to sales tax.
        
        Return ONLY a JSON object with the tax rate:
        {"taxRate": 6.0}
        
        If the item name is ambiguous or you cannot determine the tax rate, use:
        {"taxRate": null}
        """
        
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 100
        ]
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = response.choices.first?.message.content else {
            throw NSError(domain: "OpenAIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No response content"])
        }
        
        // Debug logging for token usage
        if let usage = response.usage {
            print("Tax analysis - Actual tokens: input=\(usage.prompt_tokens), output=\(usage.completion_tokens), total=\(usage.total_tokens)")
            let estimatedInput = estimateTokens(prompt)
            let estimatedOutput = estimateTokens(content)
            print("Tax analysis - Estimated tokens: input=\(estimatedInput), output=\(estimatedOutput)")
            print("Tax analysis - Estimation accuracy: input=\(Int((Double(estimatedInput)/Double(usage.prompt_tokens))*100))%, output=\(Int((Double(estimatedOutput)/Double(usage.completion_tokens))*100))%")
        } else {
            print("Tax analysis - No usage data returned from API, using estimates")
            let estimatedInput = estimateTokens(prompt)
            let estimatedOutput = estimateTokens(content)
            print("Tax analysis - Using estimates: input=\(estimatedInput), output=\(estimatedOutput)")
        }
        
        let cleanedContent = extractJSON(from: content)
        
        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw NSError(domain: "OpenAIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response to data"])
        }
        
        struct TaxResponse: Codable {
            let taxRate: Double?
        }
        
        do {
            let taxResponse = try JSONDecoder().decode(TaxResponse.self, from: jsonData)
            
            // Track this interaction with actual token usage if available
            let inputTokens = response.usage?.prompt_tokens ?? estimateTokens(prompt)
            let outputTokens = response.usage?.completion_tokens ?? estimateTokens(content)
            let cost = calculateCost(inputTokens: inputTokens, outputTokens: outputTokens, isImage: false)
            
            let historyItem = PromptHistoryItem(
                timestamp: Date(),
                type: "Tax Lookup",
                prompt: prompt,
                response: content,
                estimatedCost: cost,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                itemName: itemName
            )
            addToHistory(historyItem)
            
            return taxResponse.taxRate
        } catch {
            print("Tax lookup error: \(error)")
            print("Raw content: \(content)")
            print("Cleaned content: \(cleanedContent)")
            return nil
        }
    }
    
    func analyzePriceTag(image: UIImage, location: String? = nil) async throws -> PriceTagInfo {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let locationContext = location != nil ? " The user is located in \(location!). Look up the correct sales tax rate for this specific location." : " No location provided."
        
        let prompt = """
        Analyze this price tag image and extract the following information in JSON format:
        - name: The product name (if not readable, use "Unknown Item")
        - price: The price as a number (without currency symbols, if not readable use 0)
        - taxRate: The tax rate as a number (if you can determine it from location or price tag, otherwise null)
        - taxDescription: Description of tax rate source (e.g., "Idaho State Tax 6%" or "Unknown Taxes" if taxRate is null)
        - ingredients: Full ingredients list as a single string if visible on the package (if not visible, use null)
        
        \(locationContext)
        
        IMPORTANT: If the extracted product name is ambiguous, unclear, generic (like "test", "123", "item", "thing"), or doesn't represent a real identifiable product, set taxRate to null and taxDescription to "Unknown Taxes".
        
        Only provide a tax rate if the product name clearly represents a real, identifiable product that would be subject to sales tax.
        
        For ingredients, look for any text that lists ingredients, additives, preservatives, or nutritional components. Extract the full text as it appears.
        
        Return ONLY valid JSON in this exact format:
        {"name": "Product Name", "price": 12.99, "taxRate": 6.0, "taxDescription": "Idaho State Tax 6%", "ingredients": "Water, Sugar, Citric Acid, Natural Flavors"}
        
        If the item is ambiguous or you cannot determine the tax rate, use:
        {"name": "Product Name", "price": 12.99, "taxRate": null, "taxDescription": "Unknown Taxes", "ingredients": null}
        """
        
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 300
        ]
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = response.choices.first?.message.content else {
            throw NSError(domain: "OpenAIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No response content"])
        }
        
        // Debug logging for token usage
        if let usage = response.usage {
            print("Image analysis - Actual tokens: input=\(usage.prompt_tokens), output=\(usage.completion_tokens), total=\(usage.total_tokens)")
        } else {
            print("Image analysis - No usage data returned from API, using estimates")
        }
        
        // Clean the response content to extract JSON
        let cleanedContent = extractJSON(from: content)
        
        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw NSError(domain: "OpenAIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response to data"])
        }
        
        do {
            let result = try JSONDecoder().decode(PriceTagInfo.self, from: jsonData)
            
            // Track this interaction with actual token usage if available
            let inputTokens = response.usage?.prompt_tokens ?? (estimateTokens(prompt) + 765) // Add ~765 tokens for image if no usage data
            let outputTokens = response.usage?.completion_tokens ?? estimateTokens(content)
            let cost = calculateCost(inputTokens: inputTokens, outputTokens: outputTokens, isImage: true)
            
            let historyItem = PromptHistoryItem(
                timestamp: Date(),
                type: "Image Analysis",
                prompt: prompt,
                response: content,
                estimatedCost: cost,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                itemName: result.name
            )
            addToHistory(historyItem)
            
            return result
        } catch {
            print("JSON parsing error: \(error)")
            print("Raw content: \(content)")
            print("Cleaned content: \(cleanedContent)")
            throw NSError(domain: "OpenAIError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON response: \(error.localizedDescription)"])
        }
    }
    
    func analyzeProductForAdditiveCounts(productName: String) async throws -> (risky: Int, safe: Int, additiveDetails: [AdditiveInfo])? {
        let prompt = """
        Analyze the additives in \(productName) and provide detailed information.
        
        List the specific additives found in this product, categorizing them as risky or safe:
        
        Risky additives include: artificial colors (Red 40, Yellow 5, Blue 1, etc.), preservatives (BHA, BHT, TBHQ), artificial sweeteners (Aspartame, Sucralose), MSG, nitrites, nitrates, high fructose corn syrup, and similar chemicals.
        
        Safe additives include: vitamins, natural acids (citric acid, lactic acid), natural thickeners (xanthan gum, pectin), natural colorings (beta-carotene, turmeric), and similar natural ingredients.
        
        IMPORTANT: Only analyze if this is a real, identifiable food or beverage product. If the product name is ambiguous, unclear, or generic, return null.
        
        Return ONLY a JSON object with detailed additive information:
        {
          "riskyAdditives": [
            {"name": "Red Dye #40", "riskLevel": "High Risk", "description": "Artificial coloring linked to hyperactivity"},
            {"name": "Sodium Benzoate", "riskLevel": "Medium Risk", "description": "Preservative that may form benzene"}
          ],
          "safeAdditives": [
            {"name": "Citric Acid", "description": "Natural preservative from citrus fruits"},
            {"name": "Vitamin C", "description": "Essential nutrient and antioxidant"}
          ]
        }
        
        If you cannot determine ingredients for this product, use:
        {"riskyAdditives": null, "safeAdditives": null}
        """
        
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 200
        ]
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = response.choices.first?.message.content else {
            throw NSError(domain: "OpenAIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No response content"])
        }
        
        // Debug logging for token usage
        if let usage = response.usage {
            print("Additive count analysis - Actual tokens: input=\(usage.prompt_tokens), output=\(usage.completion_tokens), total=\(usage.total_tokens)")
        } else {
            print("Additive count analysis - No usage data returned from API, using estimates")
        }
        
        let cleanedContent = extractJSON(from: content)
        
        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw NSError(domain: "OpenAIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response to data"])
        }
        
        struct AIAdditiveDetail: Codable {
            let name: String
            let riskLevel: String?
            let description: String
        }
        
        struct DetailedAdditivesResponse: Codable {
            let riskyAdditives: [AIAdditiveDetail]?
            let safeAdditives: [AIAdditiveDetail]?
        }
        
        do {
            let additivesResponse = try JSONDecoder().decode(DetailedAdditivesResponse.self, from: jsonData)
            
            let inputTokens = response.usage?.prompt_tokens ?? estimateTokens(prompt)
            let outputTokens = response.usage?.completion_tokens ?? estimateTokens(content)
            let cost = calculateCost(inputTokens: inputTokens, outputTokens: outputTokens, isImage: false)
            
            let historyItem = PromptHistoryItem(
                timestamp: Date(),
                type: "Ingredient Analysis",
                prompt: prompt,
                response: content,
                estimatedCost: cost,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                itemName: productName
            )
            addToHistory(historyItem)
            
            if let riskyList = additivesResponse.riskyAdditives, let safeList = additivesResponse.safeAdditives {
                var additiveDetails: [AdditiveInfo] = []
                
                for risky in riskyList {
                    additiveDetails.append(AdditiveInfo(
                        name: risky.name,
                        isRisky: true,
                        riskLevel: risky.riskLevel ?? "Medium Risk",
                        description: risky.description
                    ))
                }
                
                for safe in safeList {
                    additiveDetails.append(AdditiveInfo(
                        name: safe.name,
                        isRisky: false,
                        riskLevel: "Safe",
                        description: safe.description
                    ))
                }
                
                return (risky: riskyList.count, safe: safeList.count, additiveDetails: additiveDetails)
            } else {
                return nil
            }
        } catch {
            print("Ingredient analysis error: \(error)")
            print("Raw content: \(content)")
            print("Cleaned content: \(cleanedContent)")
            return nil
        }
    }
    
    func analyzeProductForAdditives(productName: String) async throws -> String? {
        let prompt = """
        Based on the product name "\(productName)", provide the typical ingredients list for this product if it's a commonly known food or beverage item.
        
        IMPORTANT: Only provide ingredients if the product name clearly represents a real, identifiable food or beverage product with known ingredients.
        
        If the product name is ambiguous, unclear, generic (like "test", "123", "item", "thing"), or doesn't represent a real food/beverage product, return null.
        
        Return ONLY a JSON object with the ingredients:
        {"ingredients": "Water, Sugar, Citric Acid, Natural Flavors, Red Dye #40"}
        
        If you cannot determine typical ingredients for this product, use:
        {"ingredients": null}
        """
        
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 200
        ]
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = response.choices.first?.message.content else {
            throw NSError(domain: "OpenAIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No response content"])
        }
        
        // Debug logging for token usage
        if let usage = response.usage {
            print("Ingredient analysis (old method) - Actual tokens: input=\(usage.prompt_tokens), output=\(usage.completion_tokens), total=\(usage.total_tokens)")
        } else {
            print("Ingredient analysis (old method) - No usage data returned from API, using estimates")
        }
        
        let cleanedContent = extractJSON(from: content)
        
        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw NSError(domain: "OpenAIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response to data"])
        }
        
        struct IngredientsResponse: Codable {
            let ingredients: String?
        }
        
        do {
            let ingredientsResponse = try JSONDecoder().decode(IngredientsResponse.self, from: jsonData)
            
            let inputTokens = response.usage?.prompt_tokens ?? estimateTokens(prompt)
            let outputTokens = response.usage?.completion_tokens ?? estimateTokens(content)
            let cost = calculateCost(inputTokens: inputTokens, outputTokens: outputTokens, isImage: false)
            
            let historyItem = PromptHistoryItem(
                timestamp: Date(),
                type: "Ingredient Analysis",
                prompt: prompt,
                response: content,
                estimatedCost: cost,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                itemName: productName
            )
            addToHistory(historyItem)
            
            return ingredientsResponse.ingredients
        } catch {
            print("Ingredient analysis error: \(error)")
            print("Raw content: \(content)")
            print("Cleaned content: \(cleanedContent)")
            return nil
        }
    }
    
    private func extractJSON(from content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find the JSON object boundaries
        guard let startIndex = trimmed.firstIndex(of: "{"),
              let endIndex = trimmed.lastIndex(of: "}") else {
            return trimmed
        }
        
        // Extract just the JSON object
        let jsonPart = String(trimmed[startIndex...endIndex])
        return jsonPart.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func addToHistory(_ item: PromptHistoryItem) {
        DispatchQueue.main.async {
            // Add cost to total and increment count
            self.totalSpentAllTime += item.estimatedCost
            self.totalPromptCount += 1
            
            // Update type-specific tracking
            if item.type == "Image Analysis" {
                self.totalImageAnalysisCount += 1
                self.totalImageAnalysisCost += item.estimatedCost
                UserDefaults.standard.set(self.totalImageAnalysisCount, forKey: self.totalImageAnalysisCountKey)
                UserDefaults.standard.set(self.totalImageAnalysisCost, forKey: self.totalImageAnalysisCostKey)
            } else if item.type == "Tax Lookup" {
                self.totalTaxLookupCount += 1
                self.totalTaxLookupCost += item.estimatedCost
                UserDefaults.standard.set(self.totalTaxLookupCount, forKey: self.totalTaxLookupCountKey)
                UserDefaults.standard.set(self.totalTaxLookupCost, forKey: self.totalTaxLookupCostKey)
            }
            
            UserDefaults.standard.set(self.totalSpentAllTime, forKey: self.totalSpentKey)
            UserDefaults.standard.set(self.totalPromptCount, forKey: self.totalCountKey)
            
            self.promptHistory.insert(item, at: 0) // Add to beginning for newest first
            
            // Keep only last 20 items for display
            if self.promptHistory.count > 20 {
                self.promptHistory = Array(self.promptHistory.prefix(20))
            }
            
            self.savePromptHistory()
        }
    }
    
    private func savePromptHistory() {
        if let encoded = try? JSONEncoder().encode(promptHistory) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }
    
    private func loadPromptHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([PromptHistoryItem].self, from: data) {
            promptHistory = decoded
        }
    }
    
    func clearPromptHistory() {
        DispatchQueue.main.async {
            self.promptHistory.removeAll()
            self.savePromptHistory()
        }
    }
    
    func removePromptHistoryItem(at index: Int) {
        DispatchQueue.main.async {
            guard index < self.promptHistory.count else { return }
            self.promptHistory.remove(at: index)
            self.savePromptHistory()
        }
    }
    
    var totalSpent: Double {
        return totalSpentAllTime + manualSpentAdjustment
    }
    
    // Billing Management
    @Published var initialCredits: Double {
        didSet {
            UserDefaults.standard.set(initialCredits, forKey: initialCreditsKey)
        }
    }
    
    @Published var manualSpentAdjustment: Double {
        didSet {
            UserDefaults.standard.set(manualSpentAdjustment, forKey: manualSpentKey)
        }
    }
    
    var actualTotalSpent: Double {
        return totalSpent + manualSpentAdjustment
    }
    
    var remainingCredits: Double {
        return max(0, initialCredits - actualTotalSpent)
    }
    
    var creditsUsedPercentage: Double {
        guard initialCredits > 0 else { return 0 }
        return min(1.0, actualTotalSpent / initialCredits)
    }
    
    func setInitialCredits(_ amount: Double) {
        DispatchQueue.main.async {
            self.initialCredits = amount
        }
    }
    
    func setTotalSpent(_ amount: Double) {
        DispatchQueue.main.async {
            // Calculate what the manual adjustment should be
            self.manualSpentAdjustment = amount - self.totalSpent
        }
    }
    
    func resetBilling() {
        DispatchQueue.main.async {
            self.clearPromptHistory()
            self.manualSpentAdjustment = 0.0
            // Note: This will reset totalSpent to 0 since it's calculated from promptHistory
        }
    }
    
    // Usage Estimates
    var averageImageAnalysisCost: Double {
        guard totalImageAnalysisCount > 0 else { return 0.003 } // Default estimate
        return totalImageAnalysisCost / Double(totalImageAnalysisCount)
    }
    
    var averageTaxLookupCost: Double {
        guard totalTaxLookupCount > 0 else { return 0.001 } // Default estimate
        return totalTaxLookupCost / Double(totalTaxLookupCount)
    }
    
    var estimatedScansRemaining: Int? {
        guard remainingCredits > 0 && totalImageAnalysisCount > 0 else { return nil }
        return Int(remainingCredits / averageImageAnalysisCost)
    }
    
    var estimatedManualInteractionsRemaining: Int? {
        guard remainingCredits > 0 && totalTaxLookupCount > 0 else { return nil }
        return Int(remainingCredits / averageTaxLookupCost)
    }
    
    private func estimateTokens(_ text: String) -> Int {
        // Improved token estimation based on OpenAI's cl100k_base tokenizer patterns
        // Research shows ~1 token per 4 characters is a better baseline for GPT models
        
        let characterCount = text.count
        let baseEstimate = max(1, characterCount / 4)
        
        // Adjustments for different content types
        var tokenCount = baseEstimate
        
        // Add overhead for JSON structure (common in our API calls)
        if text.contains("{") || text.contains("[") {
            tokenCount = Int(Double(tokenCount) * 1.15) // 15% overhead for JSON
        }
        
        // Add overhead for complex punctuation and special characters
        let specialCharCount = text.filter { ".,!?;:()[]{}\"'`-_=+*/\\|@#$%^&<>".contains($0) }.count
        if specialCharCount > characterCount / 20 { // If >5% special chars
            tokenCount = Int(Double(tokenCount) * 1.1) // 10% overhead
        }
        
        // Add overhead for newlines and formatting (common in prompts)
        let newlineCount = text.filter { $0.isNewline }.count
        if newlineCount > 5 {
            tokenCount += newlineCount / 2 // Each newline pair ~= 1 token
        }
        
        // Conservative multiplier to account for tokenizer complexity
        tokenCount = Int(Double(tokenCount) * 1.2)
        
        return max(1, tokenCount)
    }
    
    private func calculateCost(inputTokens: Int, outputTokens: Int, isImage: Bool) -> Double {
        // GPT-4o-mini pricing (as of 2024)
        let inputCostPer1K = 0.000150  // $0.000150 per 1K input tokens
        let outputCostPer1K = 0.000600 // $0.000600 per 1K output tokens
        
        let inputCost = (Double(inputTokens) / 1000.0) * inputCostPer1K
        let outputCost = (Double(outputTokens) / 1000.0) * outputCostPer1K
        
        return inputCost + outputCost
    }
}