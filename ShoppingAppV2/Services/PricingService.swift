import Foundation

class PricingService {
    static let shared = PricingService()
    
    private init() {}
    
    // Pricing rates per million tokens (as of 2025)
    private let modelPricing: [String: ModelPricing] = [
        "gpt-4o-mini": ModelPricing(
            inputPerMillion: 0.15,
            outputPerMillion: 0.60,
            provider: "OpenAI"
        ),
        "sonar": ModelPricing(
            inputPerMillion: 1.0,
            outputPerMillion: 1.0,
            provider: "Perplexity"
        ),
        "sonar-pro": ModelPricing(
            inputPerMillion: 3.0,
            outputPerMillion: 15.0,
            provider: "Perplexity"
        )
    ]
    
    func calculateCost(for model: String, inputTokens: Int, outputTokens: Int) -> Double {
        guard let pricing = modelPricing[model] else {
            print("⚠️ Unknown model pricing for \(model), using default rates")
            return calculateDefaultCost(inputTokens: inputTokens, outputTokens: outputTokens)
        }
        
        let inputCost = (Double(inputTokens) / 1_000_000.0) * pricing.inputPerMillion
        let outputCost = (Double(outputTokens) / 1_000_000.0) * pricing.outputPerMillion
        
        return inputCost + outputCost
    }
    
    func getProvider(for model: String) -> String {
        return modelPricing[model]?.provider ?? "Unknown"
    }
    
    func getInputRate(for model: String) -> Double {
        return modelPricing[model]?.inputPerMillion ?? 1.0
    }
    
    func getOutputRate(for model: String) -> Double {
        return modelPricing[model]?.outputPerMillion ?? 1.0
    }
    
    func getAllSupportedModels() -> [String] {
        return Array(modelPricing.keys).sorted()
    }
    
    private func calculateDefaultCost(inputTokens: Int, outputTokens: Int) -> Double {
        // Fallback to reasonable default pricing (between sonar and gpt-4o-mini rates)
        let defaultInputRate = 0.5 // $0.50 per million
        let defaultOutputRate = 1.0 // $1.00 per million
        
        let inputCost = (Double(inputTokens) / 1_000_000.0) * defaultInputRate
        let outputCost = (Double(outputTokens) / 1_000_000.0) * defaultOutputRate
        
        return inputCost + outputCost
    }
}

private struct ModelPricing {
    let inputPerMillion: Double   // Cost per million input tokens
    let outputPerMillion: Double  // Cost per million output tokens
    let provider: String         // Provider name (OpenAI, Perplexity, etc.)
}