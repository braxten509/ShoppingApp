//
//  AIProviderProtocol.swift
//  ShoppingAppV2
//
//  Created by Braxten Chenay on 6/28/25.
//

import UIKit

struct TokenUsage {
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCost: Double
}

protocol AIProvider {
    var name: String { get }
    var apiKey: String { get set }
    var baseURL: String { get }
    
    func analyzeImage(image: UIImage, prompt: String, maxTokens: Int) async throws -> (response: String, usage: TokenUsage?)
    func analyzeText(prompt: String, maxTokens: Int, temperature: Double?) async throws -> (response: String, usage: TokenUsage?)
    func calculateCost(inputTokens: Int, outputTokens: Int, isImageAnalysis: Bool) -> Double
}
