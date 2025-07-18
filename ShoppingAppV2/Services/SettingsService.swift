
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
        self.manualTaxRate = UserDefaults.standard.double(forKey: "manualTaxRate")
    }
    
    
    func getTaxRatePrompt(itemName: String, location: String?) -> String {
        if let location = location {
            return "What is the sales tax rate for \(itemName) in \(location)? Respond with ONLY a JSON object: {\"taxRate\": <number>} where <number> is the tax percentage (e.g., 6.0 for 6%)."
        } else {
            return "What is the sales tax rate for \(itemName)? Respond with ONLY a JSON object: {\"taxRate\": <number>} where <number> is the tax percentage (e.g., 6.0 for 6%)."
        }
    }
    
    
    func resetAllModels() {
        selectedModelForTaxRate = "sonar-pro"
        selectedModelForPhotoPrice = "sonar-pro"
        selectedModelForTagIdentification = "sonar-pro"
    }
}
