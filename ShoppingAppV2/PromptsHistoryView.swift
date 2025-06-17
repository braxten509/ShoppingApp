import SwiftUI

struct PromptsHistoryView: View {
    @ObservedObject var openAIService: OpenAIService
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPrompt: PromptHistoryItem?
    @State private var showingClearConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                if openAIService.promptHistory.isEmpty {
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
                    ForEach(openAIService.promptHistory) { item in
                        Button(action: {
                            selectedPrompt = item
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.type)
                                        .font(.headline)
                                        .foregroundColor(item.type == "Image Analysis" ? .purple : .orange)
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("$\(item.estimatedCost, specifier: "%.6f")")
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
                        .buttonStyle(PlainButtonStyle())
                    }
                    .onDelete(perform: deletePromptHistoryItems)
                    
                    // Show indicator for hidden prompts
                    if openAIService.totalPromptCount > openAIService.promptHistory.count {
                        let hiddenCount = openAIService.totalPromptCount - openAIService.promptHistory.count
                        Section {
                            HStack {
                                Spacer()
                                Text("+\(hiddenCount) Others")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Prompt History (\(openAIService.totalPromptCount))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if !openAIService.promptHistory.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            showingClearConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .sheet(item: $selectedPrompt) { prompt in
                PromptDetailView(prompt: prompt)
            }
            .alert("Clear Prompt History", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    openAIService.clearPromptHistory()
                }
            } message: {
                Text("Are you sure you want to clear the \(openAIService.promptHistory.count) visible prompt interactions? This will not affect your billing totals.")
            }
        }
    }
    
    private func deletePromptHistoryItems(offsets: IndexSet) {
        for index in offsets {
            openAIService.removePromptHistoryItem(at: index)
        }
    }
}

struct PromptDetailView: View {
    let prompt: PromptHistoryItem
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Info
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(prompt.type)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(prompt.type == "Image Analysis" ? .purple : .orange)
                            
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
                                Text("$\(prompt.estimatedCost, specifier: "%.6f")")
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
    }
}