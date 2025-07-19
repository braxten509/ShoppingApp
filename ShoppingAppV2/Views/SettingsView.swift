import SwiftUI

struct SettingsView: View {
    @ObservedObject var openAIService: OpenAIService
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var store: ShoppingListStore
    @ObservedObject var historyService: HistoryService
    @Environment(\.presentationMode) var presentationMode
    @State private var showingPromptsHistory = false
    @State private var apiKeyInput: String = ""
    @State private var perplexityApiKeyInput: String = ""
    @State private var showingAPIKeyAlert = false
    @State private var showingPerplexityAPIKeyAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeletePerplexityConfirmation = false
    @State private var showingExportSheet = false
    @State private var exportDocument: ShoppingDataDocument?
    @State private var showingPromptCustomization = false
    
    var body: some View {
        NavigationStack {
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
                                Text("Manage OpenAI and Perplexity keys")
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
                    
                    NavigationLink(destination: StoreManagementView(settingsService: settingsService)) {
                        HStack {
                            Image(systemName: "storefront")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Store Management")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Configure stores for price search")
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
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Use Manual Tax Rate", isOn: $settingsService.useManualTaxRate)
                            .font(.headline)
                        
                        if settingsService.useManualTaxRate {
                            HStack {
                                Text("Tax Rate:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                TextField("0.0", value: $settingsService.manualTaxRate, format: .number)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                                    .keyboardType(.decimalPad)
                                    .keyboardToolbar()
                                
                                Text("%")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Tax Settings")
                } footer: {
                    if settingsService.useManualTaxRate {
                        Text("Manual tax rate will override AI-based tax detection for all items.")
                    } else {
                        Text("AI will determine tax rates based on item type and location.")
                    }
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
        settingsService: SettingsService(),
        store: ShoppingListStore(),
        historyService: HistoryService()
    )
}
