import SwiftUI

struct BillingView: View {
    @ObservedObject var openAIService: OpenAIService
    @Environment(\.presentationMode) var presentationMode
    @State private var showingEditOptions = false
    @State private var showingEditCredits = false
    @State private var showingEditSpent = false
    @State private var showingResetConfirmation = false
    @State private var newCreditsString = ""
    @State private var newSpentString = ""
    
    var body: some View {
        NavigationView {
            List {
                // Current Balance Section
                Section {
                    VStack(spacing: 16) {
                        // Credits Overview
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Credits Spent")
                                    .font(.headline)
                                Spacer()
                                Button("Edit") {
                                    showingEditOptions = true
                                }
                                .font(.caption)
                                .buttonStyle(BorderedButtonStyle())
                                .controlSize(.small)
                            }
                            
                            HStack(spacing: 3) {
                                Text("$\(openAIService.actualTotalSpent, specifier: "%.6f")")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                Text("/")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                Text("$\(formatCurrency(openAIService.initialCredits))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Text("Remaining:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("$\(openAIService.remainingCredits, specifier: "%.6f")")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(openAIService.remainingCredits > 0 ? .green : .red)
                                Spacer()
                            }
                        }
                        
                        // Progress Bar
                        if openAIService.initialCredits > 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Usage:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(openAIService.creditsUsedPercentage * 100, specifier: "%.1f")% used")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                ProgressView(value: openAIService.creditsUsedPercentage)
                                    .progressViewStyle(LinearProgressViewStyle(tint: progressBarColor))
                                    .scaleEffect(x: 1, y: 2, anchor: .center)
                            }
                        }
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button("Reset Billing") {
                                showingResetConfirmation = true
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("API Credits")
                } footer: {
                    if openAIService.initialCredits == 0 {
                        Text("Set your API budget to track spending against your allocated amount.")
                            .font(.caption)
                    }
                }
                
                // Usage Estimates
                if openAIService.remainingCredits > 0 && !openAIService.promptHistory.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "camera.fill")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                        Text("Scans Remaining")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    if let scansRemaining = openAIService.estimatedScansRemaining {
                                        Text("\(scansRemaining)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.purple)
                                    } else {
                                        Text("Unknown")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    HStack {
                                        Text("Manual Entries")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Image(systemName: "plus")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    if let manualRemaining = openAIService.estimatedManualInteractionsRemaining {
                                        Text("\(manualRemaining)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("Unknown")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            VStack(spacing: 6) {
                                HStack {
                                    Text("Based on average costs:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                
                                HStack {
                                    let imageAnalysisItems = openAIService.promptHistory.filter { $0.type == "Image Analysis" }
                                    if !imageAnalysisItems.isEmpty {
                                        Text("• Scans: $\(openAIService.averageImageAnalysisCost, specifier: "%.6f") each")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("• Scans: No history yet")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                
                                HStack {
                                    let taxLookupItems = openAIService.promptHistory.filter { $0.type == "Tax Lookup" }
                                    if !taxLookupItems.isEmpty {
                                        Text("• Manual: $\(openAIService.averageTaxLookupCost, specifier: "%.6f") each")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("• Manual: No history yet")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Estimated Usage Remaining")
                    } footer: {
                        Text("Estimates based on your actual usage patterns. Costs may vary depending on item complexity and response length.")
                            .font(.caption)
                    }
                }
                
                // Usage Breakdown
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Spent")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("$\(openAIService.actualTotalSpent, specifier: "%.6f")")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Interactions")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(openAIService.totalPromptCount)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                if openAIService.totalPromptCount > openAIService.promptHistory.count {
                                    Text("(\(openAIService.promptHistory.count) shown)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Breakdown of spending
                        VStack(spacing: 8) {
                            HStack {
                                Text("• Tracked interactions:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("$\(openAIService.totalSpent, specifier: "%.6f")")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            let manualAdjustment = openAIService.actualTotalSpent - openAIService.totalSpent
                            if manualAdjustment != 0 {
                                HStack {
                                    Text("• Manual adjustment:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(manualAdjustment >= 0 ? "+" : "")$\(manualAdjustment, specifier: "%.6f")")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(manualAdjustment >= 0 ? .orange : .green)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if !openAIService.promptHistory.isEmpty {
                        let imageAnalysisCount = openAIService.promptHistory.filter { $0.type == "Image Analysis" }.count
                        let taxLookupCount = openAIService.promptHistory.filter { $0.type == "Tax Lookup" }.count
                        let imageAnalysisCost = openAIService.promptHistory.filter { $0.type == "Image Analysis" }.reduce(0) { $0 + $1.estimatedCost }
                        let taxLookupCost = openAIService.promptHistory.filter { $0.type == "Tax Lookup" }.reduce(0) { $0 + $1.estimatedCost }
                        
                        Divider()
                        
                        VStack(spacing: 8) {
                            HStack {
                                HStack {
                                    Circle()
                                        .fill(Color.purple)
                                        .frame(width: 8, height: 8)
                                    Text("Image Analysis")
                                        .font(.caption)
                                }
                                Spacer()
                                Text("\(imageAnalysisCount)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("$\(imageAnalysisCost, specifier: "%.6f")")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                HStack {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 8, height: 8)
                                    Text("Tax Lookup")
                                        .font(.caption)
                                }
                                Spacer()
                                Text("\(taxLookupCount)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("$\(taxLookupCost, specifier: "%.6f")")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                } header: {
                    Text("Usage Breakdown")
                }
                
                // Low Balance Warning
                if openAIService.initialCredits > 0 && openAIService.creditsUsedPercentage > 0.8 {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Low Balance Warning")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                Text("You've used \(openAIService.creditsUsedPercentage * 100, specifier: "%.1f")% of your API credits.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Billing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Set API Budget", isPresented: $showingEditCredits) {
                TextField("Amount", text: $newCreditsString)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    if let amount = Double(newCreditsString), amount >= 0 {
                        openAIService.setInitialCredits(amount)
                    }
                }
            } message: {
                Text("Enter your API budget amount to track spending against this limit.")
            }
            .alert("Reset Billing", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset All", role: .destructive) {
                    openAIService.resetBilling()
                }
            } message: {
                Text("This will clear all recorded API usage and reset your spending to $0.00. Your budget amount will remain unchanged. This action cannot be undone.")
            }
            .alert("Edit Total Spent", isPresented: $showingEditSpent) {
                TextField("Amount", text: $newSpentString)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    if let amount = Double(newSpentString), amount >= 0 {
                        openAIService.setTotalSpent(amount)
                    }
                }
            } message: {
                Text("Enter the total amount you've spent. This adjusts your total spending without deleting usage breakdown data.")
            }
            .actionSheet(isPresented: $showingEditOptions) {
                ActionSheet(
                    title: Text("Edit Values"),
                    message: Text("Choose what you'd like to edit"),
                    buttons: [
                        .default(Text("Edit Budget Amount")) {
                            newCreditsString = formatCurrency(openAIService.initialCredits)
                            showingEditCredits = true
                        },
                        .default(Text("Edit Total Spent")) {
                            newSpentString = String(format: "%.6f", openAIService.actualTotalSpent)
                            showingEditSpent = true
                        },
                        .cancel()
                    ]
                )
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
    
    private var progressBarColor: Color {
        let percentage = openAIService.creditsUsedPercentage
        if percentage < 0.5 {
            return .green
        } else if percentage < 0.8 {
            return .orange
        } else {
            return .red
        }
    }
}