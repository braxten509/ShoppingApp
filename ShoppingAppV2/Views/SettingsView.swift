import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var openAIService: OpenAIService
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var store: ShoppingListStore
    @ObservedObject var historyService: HistoryService
    @ObservedObject var customPriceListStore: CustomPriceListStore
    @ObservedObject var aiService: AIService
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var billingService: BillingService
    @Environment(\.presentationMode) var presentationMode
    @State private var showingPromptsHistory = false
    @State private var apiKeyInput: String = ""
    @State private var perplexityApiKeyInput: String = ""
    @State private var showingAPIKeyAlert = false
    @State private var showingPerplexityAPIKeyAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeletePerplexityConfirmation = false
    @State private var showingFileExporter = false
    @State private var exportDocument: ShoppingDataDocument?
    @State private var showingPromptCustomization = false
    @State private var showingImportSheet = false
    @State private var showingImportAlert = false
    @State private var importAlertMessage = ""
    
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
                    
                    NavigationLink(destination: TaxSettingsView(settingsService: settingsService)) {
                        HStack {
                            Image(systemName: "percent")
                                .foregroundColor(.cyan)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tax")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Configure tax calculation settings")
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
                    
                    NavigationLink(destination: CustomPriceListsView(customPriceListStore: customPriceListStore, settingsService: settingsService)) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Custom Price Lists")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Create and manage custom stores")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    NavigationLink(destination: PrivacyView(settingsService: settingsService)) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Privacy")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Manage app features and data usage")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    NavigationLink(destination: DeveloperToolsView(aiService: aiService, settingsService: settingsService, locationManager: locationManager, billingService: billingService, historyService: historyService)) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Developer Tools")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Testing and development utilities")
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
                                Text("Share Current Shopping List")
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
                    
                    Button(action: {
                        showingImportSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Import Shopping List")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Load from file")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                } header: {
                    Text("Data Management")
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
            .fileExporter(
                isPresented: $showingFileExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: FileMigrationManager.shared.generateExportFilename()
            ) { result in
                switch result {
                case .success(_):
                    break // File exported successfully
                case .failure(let error):
                    print("File export failed: \(error)")
                }
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        importDataFromFile(url: url)
                    }
                case .failure(let error):
                    importAlertMessage = "Failed to select file: \(error.localizedDescription)"
                    showingImportAlert = true
                }
            }
            .alert("Import Status", isPresented: $showingImportAlert) {
                Button("OK") { }
            } message: {
                Text(importAlertMessage)
            }
        }
    }
    
    private func exportDataAsFile() {
        let document = FileMigrationManager.shared.createExportDocument(items: store.items)
        exportDocument = document
        showingFileExporter = true
    }
    
    private func importDataFromFile(url: URL) {
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            importAlertMessage = "Unable to access the selected file. Please try a different location."
            showingImportAlert = true
            return
        }
        
        defer {
            // Always stop accessing the resource when done
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let importedItems = try FileMigrationManager.shared.importData(from: url)
            
            if importedItems.isEmpty {
                importAlertMessage = "The file appears to be empty or contains no valid shopping items."
                showingImportAlert = true
                return
            }
            
            for item in importedItems {
                store.addItem(item)
            }
            
            importAlertMessage = "Successfully imported \(importedItems.count) item\(importedItems.count == 1 ? "" : "s") to your shopping list!"
            showingImportAlert = true
            
        } catch {
            // Provide user-friendly error messages based on error type
            if error.localizedDescription.contains("permission") || error.localizedDescription.contains("not permitted") {
                importAlertMessage = "Permission denied. Please save the file to a location like Downloads or Documents and try again."
            } else if error.localizedDescription.contains("corrupted") || error.localizedDescription.contains("format") {
                importAlertMessage = "The file appears to be corrupted or in an invalid format."
            } else {
                importAlertMessage = "Failed to import file: \(error.localizedDescription)"
            }
            showingImportAlert = true
        }
    }
}

#Preview {
    let settingsService = SettingsService()
    let billingService = BillingService()
    let historyService = HistoryService()
    return SettingsView(
        openAIService: OpenAIService(),
        settingsService: settingsService,
        store: ShoppingListStore(),
        historyService: historyService,
        customPriceListStore: CustomPriceListStore(),
        aiService: AIService(settingsService: settingsService, billingService: billingService, historyService: historyService),
        locationManager: LocationManager(),
        billingService: billingService
    )
}
