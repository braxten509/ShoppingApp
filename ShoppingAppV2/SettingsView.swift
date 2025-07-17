import SwiftUI

struct SettingsView: View {
    @ObservedObject var openAIService: OpenAIService
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var store: ShoppingListStore
    @ObservedObject var historyService: HistoryService
    @Environment(\.presentationMode) var presentationMode
    @State private var showingPromptsHistory = false
    @State private var apiKeyInput: String = ""
    @State private var perplexityApiKeyInput: String = ""
    @State private var geminiApiKeyInput: String = ""
    @State private var showingAPIKeyAlert = false
    @State private var showingPerplexityAPIKeyAlert = false
    @State private var showingGeminiAPIKeyAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeletePerplexityConfirmation = false
    @State private var showingDeleteGeminiConfirmation = false
    @State private var showingExportSheet = false
    @State private var exportDocument: ShoppingDataDocument?
    @State private var showingPromptCustomization = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: APIKeysView(settingsService: settingsService)) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("API Keys")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Manage OpenAI, Perplexity, and Gemini API keys")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    NavigationLink(destination: AISettingsView(settingsService: settingsService, historyService: historyService)) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI Settings")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Configure AI models and prompts")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            
                            Spacer()
                        }
                    }
                } header: {
                    Text("Configuration")
                }
                
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
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(store.items.isEmpty)
                } header: {
                    Text("Data Export")
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
            .sheet(isPresented: $showingExportSheet) {
                if let document = exportDocument {
                    ShareSheet(document: document, filename: FileMigrationManager.shared.generateExportFilename())
                }
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
        settingsService: SettingsService(),
        store: ShoppingListStore(),
        historyService: HistoryService()
    )
}
