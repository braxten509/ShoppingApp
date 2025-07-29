import SwiftUI

struct APIKeysView: View {
    @ObservedObject var settingsService: SettingsService
    @State private var apiKeyInput: String = ""
    @State private var perplexityApiKeyInput: String = ""
    @State private var showingAPIKeyAlert = false
    @State private var showingPerplexityAPIKeyAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeletePerplexityConfirmation = false
    
    // WebView states
    @State private var showingOpenAIKeysWeb = false
    @State private var showingOpenAIBillingWeb = false
    @State private var showingPerplexityKeysWeb = false
    @State private var showingPerplexityBillingWeb = false
    
    // Credit sync states
    @State private var showingOpenAICreditSync = false
    @State private var showingPerplexityCreditSync = false
    @State private var isSyncing = false
    
    // Manual credit input states
    @State private var showingManualOpenAIInput = false
    @State private var showingManualPerplexityInput = false
    @State private var manualCreditInput = ""
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("API Key")
                    Spacer()
                    if settingsService.openAIAPIKey.isEmpty {
                        Button(action: {
                            apiKeyInput = ""
                            showingAPIKeyAlert = true
                        }) {
                            Text("Not Set")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Text("••••••" + String(settingsService.openAIAPIKey.suffix(4)))
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
                
                Button(action: {
                    showingOpenAIKeysWeb = true
                }) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.green)
                        Text("Get API Key from OpenAI")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showingOpenAIBillingWeb = true
                }) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.orange)
                        Text("View OpenAI Billing")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Credits Display
                HStack {
                    VStack(alignment: .leading) {
                        Text("Credits")
                        Button("Manual Entry") {
                            manualCreditInput = ""
                            showingManualOpenAIInput = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    Spacer()
                    Text("$\(settingsService.formatCredits(settingsService.openAICredits))")
                        .foregroundColor(settingsService.openAICredits < 0 ? .secondary : .primary)
                }
            } header: {
                Text("OpenAI Configuration")
            }
            
            Section {
                HStack {
                    Text("API Key")
                    Spacer()
                    if settingsService.perplexityAPIKey.isEmpty {
                        Button(action: {
                            perplexityApiKeyInput = ""
                            showingPerplexityAPIKeyAlert = true
                        }) {
                            Text("Not Set")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Text("••••••" + String(settingsService.perplexityAPIKey.suffix(4)))
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
                
                Button(action: {
                    showingPerplexityKeysWeb = true
                }) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.purple)
                        Text("Get API Key from Perplexity")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showingPerplexityBillingWeb = true
                }) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.orange)
                        Text("View Perplexity Billing")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Credits Display
                HStack {
                    VStack(alignment: .leading) {
                        Text("Credits")
                        Button("Manual Entry") {
                            manualCreditInput = ""
                            showingManualPerplexityInput = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    Spacer()
                    Text("$\(settingsService.formatCredits(settingsService.perplexityCredits))")
                        .foregroundColor(settingsService.perplexityCredits < 0 ? .secondary : .primary)
                }
            } header: {
                Text("Perplexity Configuration")
            }
            
            Section {
                HStack {
                    Text("Last synced")
                        .foregroundColor(.secondary)
                    Spacer()
                    if let lastSyncDate = settingsService.lastSyncDate {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(lastSyncDate, style: .date)
                                .foregroundColor(.secondary)
                            Text(formatTimeWithTimezone(lastSyncDate))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    } else {
                        Text("Never")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("API Keys")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: syncCredits) {
                    HStack(spacing: 4) {
                        Text("Sync")
                        if isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                .disabled(isSyncing)
            }
        }
        .alert("Set OpenAI API Key", isPresented: $showingAPIKeyAlert) {
            TextField("API Key", text: $apiKeyInput)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                settingsService.openAIAPIKey = apiKeyInput
            }
        } message: {
            Text("Enter your OpenAI API key. You can find this in your OpenAI account settings.")
        }
        .alert("Delete API Key", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                settingsService.openAIAPIKey = ""
            }
        } message: {
            Text("Are you sure you want to delete your API key? You'll need to enter it again to use the app's AI features.")
        }
        .alert("Set Perplexity API Key", isPresented: $showingPerplexityAPIKeyAlert) {
            TextField("API Key", text: $perplexityApiKeyInput)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                settingsService.perplexityAPIKey = perplexityApiKeyInput
            }
        } message: {
            Text("Enter your Perplexity API key. You can find this in your Perplexity account settings.")
        }
        .alert("Delete Perplexity API Key", isPresented: $showingDeletePerplexityConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                settingsService.perplexityAPIKey = ""
            }
        } message: {
            Text("Are you sure you want to delete your Perplexity API key? You'll need to enter it again to use price search features.")
        }
        .alert("Set OpenAI Credits", isPresented: $showingManualOpenAIInput) {
            TextField("Credits Amount", text: $manualCreditInput)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let credits = Double(manualCreditInput), credits >= 0 {
                    print("💡 Manual OpenAI credit entry: $\(credits)")
                    settingsService.updateOpenAICredits(credits)
                }
            }
        } message: {
            Text("Enter your current OpenAI credit balance manually.")
        }
        .alert("Set Perplexity Credits", isPresented: $showingManualPerplexityInput) {
            TextField("Credits Amount", text: $manualCreditInput)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let credits = Double(manualCreditInput), credits >= 0 {
                    print("💡 Manual Perplexity credit entry: $\(credits)")
                    settingsService.updatePerplexityCredits(credits)
                }
            }
        } message: {
            Text("Enter your current Perplexity credit balance manually.")
        }
        .sheet(isPresented: $showingOpenAIKeysWeb) {
            SecureWebViewSheet(
                url: URL(string: "https://platform.openai.com/api-keys")!,
                title: "OpenAI API Keys",
                isPresented: $showingOpenAIKeysWeb
            )
        }
        .sheet(isPresented: $showingOpenAIBillingWeb) {
            SecureWebViewSheet(
                url: URL(string: "https://platform.openai.com/account/billing/overview")!,
                title: "OpenAI Billing",
                isPresented: $showingOpenAIBillingWeb
            )
        }
        .sheet(isPresented: $showingPerplexityKeysWeb) {
            SecureWebViewSheet(
                url: URL(string: "https://www.perplexity.ai/account/api/keys")!,
                title: "Perplexity API Keys",
                isPresented: $showingPerplexityKeysWeb
            )
        }
        .sheet(isPresented: $showingPerplexityBillingWeb) {
            SecureWebViewSheet(
                url: URL(string: "https://www.perplexity.ai/account/api/billing")!,
                title: "Perplexity API Billing",
                isPresented: $showingPerplexityBillingWeb
            )
        }
        .sheet(isPresented: $showingOpenAICreditSync) {
            CreditSyncWebView(
                url: URL(string: "https://platform.openai.com/account/billing/overview")!,
                provider: "OpenAI",
                isPresented: $showingOpenAICreditSync,
                onCreditsFound: { credits in
                    print("🔄 Updating OpenAI credits: $\(credits)")
                    settingsService.updateOpenAICredits(credits)
                    print("✅ OpenAI credits updated. New value: \(settingsService.formatCredits(settingsService.openAICredits))")
                },
                onCompleted: onOpenAISyncComplete,
                onError: { error in
                    print("❌ OpenAI credit sync error: \(error)")
                }
            )
        }
        .sheet(isPresented: $showingPerplexityCreditSync) {
            CreditSyncWebView(
                url: URL(string: "https://www.perplexity.ai/account/api/billing")!,
                provider: "Perplexity",
                isPresented: $showingPerplexityCreditSync,
                onCreditsFound: { credits in
                    print("🔄 Updating Perplexity credits: $\(credits)")
                    settingsService.updatePerplexityCredits(credits)
                    print("✅ Perplexity credits updated. New value: \(settingsService.formatCredits(settingsService.perplexityCredits))")
                },
                onCompleted: onPerplexitySyncComplete,
                onError: { error in
                    print("❌ Perplexity credit sync error: \(error)")
                }
            )
        }
    }
    
    private func syncCredits() {
        print("🔄 Starting credit sync process")
        isSyncing = true
        
        // Start with OpenAI first
        if !settingsService.openAIAPIKey.isEmpty {
            print("🔑 OpenAI API key found, starting OpenAI sync")
            showingOpenAICreditSync = true
        } else if !settingsService.perplexityAPIKey.isEmpty {
            // If no OpenAI key, try Perplexity directly
            print("🔑 Perplexity API key found, starting Perplexity sync")
            showingPerplexityCreditSync = true
        } else {
            print("⚠️ No API keys configured")
            isSyncing = false
        }
    }
    
    private func onOpenAISyncComplete() {
        print("✅ OpenAI sync completed")
        // After OpenAI sync completes, try Perplexity
        if !settingsService.perplexityAPIKey.isEmpty {
            print("🔑 Starting Perplexity sync after OpenAI")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showingPerplexityCreditSync = true
            }
        } else {
            print("✅ All syncs completed")
            isSyncing = false
        }
    }
    
    private func onPerplexitySyncComplete() {
        print("✅ Perplexity sync completed")
        print("✅ All syncs completed")
        isSyncing = false
    }
    
    private func formatTimeWithTimezone(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        
        let timeString = formatter.string(from: date)
        let timezoneAbbreviation = TimeZone.current.abbreviation() ?? ""
        
        return "\(timeString) \(timezoneAbbreviation)"
    }
}

#Preview {
    NavigationView {
        APIKeysView(settingsService: SettingsService())
    }
}
