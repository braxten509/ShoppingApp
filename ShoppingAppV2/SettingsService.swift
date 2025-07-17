
import Foundation
import Combine

enum PromptType: String, CaseIterable, Codable {
    case taxRate = "taxRate"
    case priceTagAnalysis = "priceTagAnalysis"
    case priceGuessing = "priceGuessing"
    case additiveAnalysis = "additiveAnalysis"
    
    var displayName: String {
        switch self {
        case .taxRate: return "Tax Rate Detection"
        case .priceTagAnalysis: return "Price Tag Analysis"
        case .priceGuessing: return "Price Guessing"
        case .additiveAnalysis: return "Additive Analysis"
        }
    }
    
    var description: String {
        switch self {
        case .taxRate: return "Determines tax rates for items based on name and location"
        case .priceTagAnalysis: return "Analyzes price tag images to extract product information"
        case .priceGuessing: return "Searches for current prices of items online"
        case .additiveAnalysis: return "Analyzes food additives and their safety levels"
        }
    }
}

struct CustomPrompt: Codable {
    let type: PromptType
    var template: String
    var isEnabled: Bool
    
    init(type: PromptType, template: String, isEnabled: Bool = false) {
        self.type = type
        self.template = template
        self.isEnabled = isEnabled
    }
}

class SettingsService: ObservableObject {
    @Published var useAIModels: Bool {
        didSet {
            UserDefaults.standard.set(useAIModels, forKey: "useAIModels")
        }
    }

    @Published var selectedModelForTaxRate: String {
        didSet {
            UserDefaults.standard.set(selectedModelForTaxRate, forKey: "selectedModelForTaxRate")
        }
    }

    @Published var selectedModelForPhotoPrice: String {
        didSet {
            UserDefaults.standard.set(selectedModelForPhotoPrice, forKey: "selectedModelForPhotoPrice")
        }
    }

    @Published var selectedModelForTagIdentification: String {
        didSet {
            UserDefaults.standard.set(selectedModelForTagIdentification, forKey: "selectedModelForTagIdentification")
        }
    }

    @Published var openAIAPIKey: String {
        didSet {
            UserDefaults.standard.set(openAIAPIKey, forKey: "openAIAPIKey")
        }
    }

    @Published var perplexityAPIKey: String {
        didSet {
            UserDefaults.standard.set(perplexityAPIKey, forKey: "perplexityAPIKey")
        }
    }
    
    @Published var geminiAPIKey: String {
        didSet {
            UserDefaults.standard.set(geminiAPIKey, forKey: "geminiAPIKey")
        }
    }
    
    @Published var customPrompts: [PromptType: CustomPrompt] = [:] {
        didSet {
            saveCustomPrompts()
        }
    }

    let aiModels = [
        // OpenAI Models (all have vision support)
        "gpt-4.1",
        "gpt-4.1-mini", 
        "gpt-4.1-nano",
        "gpt-4o",
        "gpt-4o-mini",
        
        // Perplexity Models (all have vision support)
        "sonar-pro",
        "sonar",
        "sonar-reasoning-pro",
        
        // Google Gemini Models (all have vision support)
        "gemini-2.5-pro",
        "gemini-2.5-flash",
        "gemini-2.0-flash-001"
    ]

    init() {
        self.useAIModels = UserDefaults.standard.bool(forKey: "useAIModels")
        self.selectedModelForTaxRate = UserDefaults.standard.string(forKey: "selectedModelForTaxRate") ?? "sonar-pro"
        self.selectedModelForPhotoPrice = UserDefaults.standard.string(forKey: "selectedModelForPhotoPrice") ?? "sonar-pro"
        self.selectedModelForTagIdentification = UserDefaults.standard.string(forKey: "selectedModelForTagIdentification") ?? "sonar-pro"
        self.openAIAPIKey = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
        self.perplexityAPIKey = UserDefaults.standard.string(forKey: "perplexityAPIKey") ?? ""
        self.geminiAPIKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        
        loadCustomPrompts()
    }
    
    private func loadCustomPrompts() {
        if let data = UserDefaults.standard.data(forKey: "customPrompts"),
           let decoded = try? JSONDecoder().decode([PromptType: CustomPrompt].self, from: data) {
            self.customPrompts = decoded
        } else {
            // Initialize with default prompts
            self.customPrompts = createDefaultPrompts()
        }
    }
    
    private func saveCustomPrompts() {
        if let encoded = try? JSONEncoder().encode(customPrompts) {
            UserDefaults.standard.set(encoded, forKey: "customPrompts")
        }
    }
    
    private func createDefaultPrompts() -> [PromptType: CustomPrompt] {
        var defaults: [PromptType: CustomPrompt] = [:]
        
        defaults[.taxRate] = CustomPrompt(
            type: .taxRate,
            template: """
            Analyze the item "{itemName}". {locationContext}
            Respond with ONLY a valid JSON object in the format {"taxRate": <rate>}.
            The <rate> should be a number representing the sales tax percentage.
            If the item is not taxable or the name is ambiguous, return {"taxRate": null}.
            """
        )
        
        defaults[.priceTagAnalysis] = CustomPrompt(
            type: .priceTagAnalysis,
            template: """
            Analyze the image. {locationContext}
            Respond with ONLY a valid JSON object in the format:
            {"name": "<item_name>", "price": <price>, "taxRate": <tax_rate>, "taxDescription": "<description>", "ingredients": "<ingredients_list>"}
            - name: "Unknown Item" if not readable.
            - price: A number, or 0 if not readable.
            - taxRate: A number, or null if unknown.
            - taxDescription: "Unknown Taxes" if tax is unknown.
            - ingredients: A single string, or null if not visible.
            """
        )
        
        defaults[.priceGuessing] = CustomPrompt(
            type: .priceGuessing,
            template: """
            Find the price of "{itemName}" {brand} {additionalDetails} at {storeName}.
            Respond with ONLY a valid JSON object in the format {"estimatedPrice": <price>, "sourceURL": "<url>"}.
            If no price is found, return {"estimatedPrice": null, "sourceURL": null}.
            """
        )
        
        defaults[.additiveAnalysis] = CustomPrompt(
            type: .additiveAnalysis,
            template: """
            Analyze the additives in "{productName}".
            Respond with ONLY a valid JSON object in the format:
            {"riskyAdditives": [{"name": "<name>", "riskLevel": "<level>", "description": "<desc>"}], "safeAdditives": [{"name": "<name>", "description": "<desc>"}]}
            If ingredients are unknown, return {"riskyAdditives": null, "safeAdditives": null}.
            """
        )
        
        return defaults
    }
    
    func getPrompt(for type: PromptType) -> String {
        if let customPrompt = customPrompts[type], customPrompt.isEnabled {
            return customPrompt.template
        }
        return createDefaultPrompts()[type]?.template ?? ""
    }
    
    func updateCustomPrompt(type: PromptType, template: String, isEnabled: Bool) {
        customPrompts[type] = CustomPrompt(type: type, template: template, isEnabled: isEnabled)
    }
    
    func resetPrompt(type: PromptType) {
        customPrompts[type] = createDefaultPrompts()[type]
    }
    
    func resetAllPrompts() {
        customPrompts = createDefaultPrompts()
    }
    
    func resetAllModels() {
        selectedModelForTaxRate = "sonar-pro"
        selectedModelForPhotoPrice = "sonar-pro"
        selectedModelForTagIdentification = "sonar-pro"
    }
}
