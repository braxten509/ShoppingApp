import SwiftUI

struct SettingsView: View {
    @ObservedObject var openAIService: OpenAIService
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var store: ShoppingListStore
    @Environment(\.presentationMode) var presentationMode
    @State private var showingPromptsHistory = false
    @State private var showingBilling = false
    @State private var apiKeyInput: String = ""
    @State private var perplexityApiKeyInput: String = ""
    @State private var showingAPIKeyAlert = false
    @State private var showingPerplexityAPIKeyAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeletePerplexityConfirmation = false
    @State private var showingExportSheet = false
    @State private var exportDocument: ShoppingDataDocument?
    
    var body: some View {
        NavigationView {
            SettingsListSection(
                openAIService: openAIService,
                settingsStore: settingsStore,
                store: store,
                showingPromptsHistory: $showingPromptsHistory,
                showingBilling: $showingBilling,
                apiKeyInput: $apiKeyInput,
                perplexityApiKeyInput: $perplexityApiKeyInput,
                showingAPIKeyAlert: $showingAPIKeyAlert,
                showingPerplexityAPIKeyAlert: $showingPerplexityAPIKeyAlert,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                showingDeletePerplexityConfirmation: $showingDeletePerplexityConfirmation,
                showingExportSheet: $showingExportSheet,
                exportDocument: $exportDocument
            )
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
            .alert("Set OpenAI API Key", isPresented: $showingAPIKeyAlert) {
                TextField("API Key", text: $apiKeyInput)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    openAIService.apiKey = apiKeyInput
                }
            } message: {
                Text("Enter your OpenAI API key. You can find this in your OpenAI account settings.")
            }
            .alert("Delete API Key", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    openAIService.clearAPIKey()
                }
            } message: {
                Text("Are you sure you want to delete your API key? You'll need to enter it again to use the app's AI features.")
            }
            .alert("Set Perplexity API Key", isPresented: $showingPerplexityAPIKeyAlert) {
                TextField("API Key", text: $perplexityApiKeyInput)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    openAIService.perplexityApiKey = perplexityApiKeyInput
                }
            } message: {
                Text("Enter your Perplexity API key. You can find this in your Perplexity account settings.")
            }
            .alert("Delete Perplexity API Key", isPresented: $showingDeletePerplexityConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    openAIService.clearPerplexityAPIKey()
                }
            } message: {
                Text("Are you sure you want to delete your Perplexity API key? You'll need to enter it again to use price search features.")
            }
            .sheet(isPresented: $showingExportSheet) {
                if let document = exportDocument {
                    ShareSheet(document: document, filename: FileMigrationManager.shared.generateExportFilename())
                }
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

private struct SettingsListSection: View {
    @ObservedObject var openAIService: OpenAIService
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var store: ShoppingListStore
    @Environment(\.presentationMode) var presentationMode
    @Binding var showingPromptsHistory: Bool
    @Binding var showingBilling: Bool
    @Binding var apiKeyInput: String
    @Binding var perplexityApiKeyInput: String
    @Binding var showingAPIKeyAlert: Bool
    @Binding var showingPerplexityAPIKeyAlert: Bool
    @Binding var showingDeleteConfirmation: Bool
    @Binding var showingDeletePerplexityConfirmation: Bool
    @Binding var showingExportSheet: Bool
    @Binding var exportDocument: ShoppingDataDocument?
    
    struct APIKeys: View {
        @ObservedObject var openAIService: OpenAIService
        @Binding var apiKeyInput: String
        @Binding var showingAPIKeyAlert: Bool
        @Binding var showingDeleteConfirmation: Bool
        
        var body: some View {
            List {
                Section("API Keys Configuration") {
                    HStack {
                        Text("OPENAI")
                        Spacer()
                        if openAIService.apiKey.isEmpty {
                            Button(action: {
                                apiKeyInput = ""
                                showingAPIKeyAlert = true
                            }) {
                                Text("Not Set")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Text("••••••" + String(openAIService.apiKey.suffix(4)))
                                .foregroundColor(.secondary)
                            Button(action: {
                                showingDeleteConfirmation = true
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }
    
    var body: some View {
        // API Key Section
        List {
            Section {
                NavigationLink("API Keys", destination: APIKeys(
                    openAIService: openAIService,
                    apiKeyInput: $apiKeyInput,
                    showingAPIKeyAlert: $showingAPIKeyAlert,
                    showingDeleteConfirmation: $showingDeleteConfirmation
                ))
                
                HStack {
                    Text("API Key")
                    Spacer()
                    if openAIService.apiKey.isEmpty {
                        Button(action: {
                            apiKeyInput = ""
                            showingAPIKeyAlert = true
                        }) {
                            Text("Not Set")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Text("••••••" + String(openAIService.apiKey.suffix(4)))
                            .foregroundColor(.secondary)
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.green)
                        Text("Get API Key from OpenAI")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
            } header: {
                Text("OpenAI Configuration")
            } footer: {
                Text("Your API key is stored securely on this device. Tap the link above to open OpenAI's API keys page in your browser.")
                    .font(.caption)
            }
            
            // Perplexity API Key Section
            Section {
                HStack {
                    Text("API Key")
                    Spacer()
                    if openAIService.perplexityApiKey.isEmpty {
                        Button(action: {
                            perplexityApiKeyInput = ""
                            showingPerplexityAPIKeyAlert = true
                        }) {
                            Text("Not Set")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Text("••••••" + String(openAIService.perplexityApiKey.suffix(4)))
                            .foregroundColor(.secondary)
                        Button(action: {
                            showingDeletePerplexityConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Link(destination: URL(string: "https://www.perplexity.ai/settings/api")!) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.purple)
                        Text("Get API Key from Perplexity")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Perplexity Configuration")
            } footer: {
                Text("Used for web-based price searches. Your API key is stored securely on this device.")
                    .font(.caption)
            }
            
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
                                Text("$\(openAIService.formatBillingCurrency(openAIService.remainingCredits))")
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
                            Text("$\(openAIService.formatBillingCurrency(openAIService.totalSpent))")
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
            
            // Data Migration Section
            Section {
                Button(action: {
                    exportDataAsFile()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Export Shopping List")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Share as file")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(store.items.isEmpty)
            } header: {
                Text("Data Export")
            } footer: {
                Text("Export your shopping list as a file that can be imported into the Combined app or shared with others.")
                    .font(.caption)
            }
        }
    }
    
    private func exportDataAsFile() {
        exportDocument = FileMigrationManager.shared.createExportDocument(items: store.items)
        showingExportSheet = true
    }
}

#Preview {
    SettingsView(
        openAIService: OpenAIService(),
        settingsStore: SettingsStore(),
        store: ShoppingListStore()
    )
}
