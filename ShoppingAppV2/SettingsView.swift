import SwiftUI

struct SettingsView: View {
    @ObservedObject var openAIService: OpenAIService
    @ObservedObject var settingsStore: SettingsStore
    @Environment(\.presentationMode) var presentationMode
    @State private var showingPromptsHistory = false
    @State private var showingBilling = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    // Billing Button
                    Button(action: {
                        showingBilling = true
                    }) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Billing")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Track API credits")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                if openAIService.initialCredits > 0 {
                                    Text("$\(formatCurrency(openAIService.remainingCredits))")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(openAIService.remainingCredits > 0 ? .primary : .red)
                                    Text("remaining")
                                        .foregroundColor(.secondary)
                                        .font(.caption2)
                                } else {
                                    Text("Not set")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Prompts Button
                    Button(action: {
                        showingPromptsHistory = true
                    }) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Prompts")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("\(openAIService.totalPromptCount) interactions")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("$\(openAIService.totalSpent, specifier: "%.6f")")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("total spent")
                                    .foregroundColor(.secondary)
                                    .font(.caption2)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                } header: {
                    Text("API Usage")
                } footer: {
                    Text("Manage your API credits and view detailed history of interactions. History shows 20 most recent, but billing tracks all interactions.")
                        .font(.caption)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPromptsHistory) {
                PromptsHistoryView(openAIService: openAIService)
            }
            .sheet(isPresented: $showingBilling) {
                BillingView(openAIService: openAIService)
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        // Remove trailing zeros but keep significant decimal places
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.usesGroupingSeparator = false
        
        if let formatted = formatter.string(from: NSNumber(value: amount)) {
            return formatted
        }
        return String(format: "%.6f", amount).trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}