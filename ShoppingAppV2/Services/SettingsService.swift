
import Foundation
import Combine


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
    
    @Published var useManualTaxRate: Bool {
        didSet {
            UserDefaults.standard.set(useManualTaxRate, forKey: "useManualTaxRate")
        }
    }
    
    @Published var manualTaxRate: Double {
        didSet {
            UserDefaults.standard.set(manualTaxRate, forKey: "manualTaxRate")
        }
    }
    

    let aiModels = [
        // OpenAI Models
        "gpt-4o-mini",
        
        // Perplexity Models
        "sonar-pro",
        "sonar"
    ]

    init() {
        self.useAIModels = UserDefaults.standard.bool(forKey: "useAIModels")
        self.selectedModelForTaxRate = UserDefaults.standard.string(forKey: "selectedModelForTaxRate") ?? "sonar-pro"
        self.selectedModelForPhotoPrice = UserDefaults.standard.string(forKey: "selectedModelForPhotoPrice") ?? "sonar-pro"
        self.selectedModelForTagIdentification = UserDefaults.standard.string(forKey: "selectedModelForTagIdentification") ?? "sonar-pro"
        self.openAIAPIKey = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
        self.perplexityAPIKey = UserDefaults.standard.string(forKey: "perplexityAPIKey") ?? ""
        self.useManualTaxRate = UserDefaults.standard.bool(forKey: "useManualTaxRate")
        // Set a reasonable default tax rate if none exists (6% is a common US average)
        let storedTaxRate = UserDefaults.standard.double(forKey: "manualTaxRate")
        self.manualTaxRate = storedTaxRate > 0 ? storedTaxRate : 6.0
    }
    
    
    func getTaxRatePrompt(itemName: String, location: String?) -> String {
        if let location = location {
            return """
            What is the current sales tax rate for purchasing \(itemName) in \(location)? 
            
            Consider:
            - State sales tax
            - Local sales tax
            - Combined total rate
            - Any special categories for this item type
            
            Respond with ONLY a JSON object in this exact format:
            {"taxRate": X.X}
            
            Where X.X is the total combined tax percentage as a decimal number (e.g., 6.0 for 6%, 8.25 for 8.25%).
            Do not include any other text, explanations, or formatting.
            """
        } else {
            return """
            What is the typical sales tax rate for purchasing \(itemName) in the United States?
            
            Provide the most common sales tax rate range for this type of item.
            If uncertain, use a reasonable estimate based on average US sales tax rates (typically 6-8%).
            
            Respond with ONLY a JSON object in this exact format:
            {"taxRate": X.X}
            
            Where X.X is the tax percentage as a decimal number (e.g., 6.0 for 6%, 7.5 for 7.5%).
            Do not include any other text, explanations, or formatting.
            """
        }
    }
    
    
    func resetAllModels() {
        selectedModelForTaxRate = "sonar-pro"
        selectedModelForPhotoPrice = "sonar-pro"
        selectedModelForTagIdentification = "sonar-pro"
    }
}
