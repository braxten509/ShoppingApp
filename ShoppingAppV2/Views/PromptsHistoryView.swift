import SwiftUI

struct PromptsHistoryView: View {
    @ObservedObject var historyService: HistoryService
    @Environment(\.presentationMode) var presentationMode
    @State private var showingClearConfirmation = false
    
    var body: some View {
        List {
            if historyService.promptHistory.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Interactions Yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Your API interactions will appear here after scanning items or detecting taxes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                ForEach(historyService.promptHistory) { item in
                    NavigationLink(destination: PromptDetailView(prompt: item)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.type)
                                        .font(.headline)
                                        .foregroundColor(colorForItem(item))
                                    
                                    if let aiService = item.aiService, let model = item.model {
                                        Text("\(aiService): \(model)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("$\(item.estimatedCost, specifier: "%.3f")")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(item.timestamp, style: .relative)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let itemName = item.itemName {
                                Text("Item: \(itemName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("\(item.inputTokens) in")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                                
                                Text("\(item.outputTokens) out")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                                
                                Spacer()
                                
                                Text("Tap for details")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deletePromptHistoryItems)
                
                // Show indicator for hidden prompts
            }
        }
        .navigationTitle("Prompt History (\(historyService.promptHistory.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
            if !historyService.promptHistory.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        showingClearConfirmation = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .alert("Clear Prompt History", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                historyService.clearAll()
            }
        } message: {
            Text("Are you sure you want to clear the \(historyService.promptHistory.count) visible prompt interactions? This will not affect your billing totals.")
        }
    }
    
    private func deletePromptHistoryItems(offsets: IndexSet) {
        for index in offsets {
            historyService.remove(at: index)
        }
    }
    
    private func colorForItem(_ item: PromptHistoryItem) -> Color {
        if let aiService = item.aiService {
            switch aiService {
            case "OpenAI":
                return .green
            case "Perplexity":
                return .blue
            default:
                return .primary
            }
        }
        // Fallback for items without aiService (older data)
        if item.type == "Image Analysis" {
            return .green
        } else if item.type.contains("Perplexity") {
            return .blue
        } else {
            return .green
        }
    }
}

struct PromptDetailView: View {
    let prompt: PromptHistoryItem
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Info
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prompt.type)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(colorForPrompt(prompt))
                            
                            if let aiService = prompt.aiService, let model = prompt.model {
                                Text("\(aiService): \(model)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text(prompt.timestamp, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(prompt.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let itemName = prompt.itemName {
                        HStack {
                            Text("Item:")
                                .fontWeight(.medium)
                            Text(itemName)
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Cost & Token Details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Usage Details")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Input Tokens")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(prompt.inputTokens)")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output Tokens")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(prompt.outputTokens)")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total Cost")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(prompt.estimatedCost, specifier: "%.3f")")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Prompt
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt Sent")
                        .font(.headline)
                    
                    Text(prompt.prompt)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                // Response
                VStack(alignment: .leading, spacing: 8) {
                    Text("Response Received")
                        .font(.headline)
                    
                    Text(prompt.response)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle("Interaction Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func colorForPrompt(_ prompt: PromptHistoryItem) -> Color {
        if let aiService = prompt.aiService {
            switch aiService {
            case "OpenAI":
                return .green
            case "Perplexity":
                return .blue
            default:
                return .primary
            }
        }
        // Fallback for items without aiService (older data)
        if prompt.type == "Image Analysis" {
            return .green
        } else if prompt.type.contains("Perplexity") {
            return .blue
        } else {
            return .green
        }
    }
}