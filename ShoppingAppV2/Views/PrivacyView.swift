import SwiftUI
import WebKit

struct PrivacyView: View {
    @ObservedObject var settingsService: SettingsService
    @Environment(\.presentationMode) var presentationMode
    @State private var showingClearCacheAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Enable Location Access", isOn: $settingsService.locationAccessEnabled)
                        .font(.headline)
                        .disabled(!settingsService.aiEnabled || !settingsService.internetAccessEnabled)
                        .foregroundColor((!settingsService.aiEnabled || !settingsService.internetAccessEnabled) ? .secondary : .primary)
                    
                    Toggle("Enable AI", isOn: $settingsService.aiEnabled)
                        .font(.headline)
                        .disabled(!settingsService.internetAccessEnabled)
                        .foregroundColor(!settingsService.internetAccessEnabled ? .secondary : .primary)
                    
                    Toggle("Enable Internet Access", isOn: $settingsService.internetAccessEnabled)
                        .font(.headline)
                } header: {
                    Text("App Features")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if !settingsService.internetAccessEnabled {
                            Text("• Internet disabled: All network-dependent features disabled")
                        } else if !settingsService.aiEnabled {
                            Text("• AI disabled: AI features and location access disabled")
                        } else if !settingsService.locationAccessEnabled {
                            Text("• Location disabled: Manual tax rate will be required")
                        } else {
                            Text("All features enabled")
                        }
                    }
                    .font(.caption)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Usage")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Location: Used for tax rate detection")
                            Text("• AI Services: Process images and text for price recognition")
                            Text("• Internet: Required for AI services and price search")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Privacy Information")
                } footer: {
                    Text("ShoppingApp processes data locally when possible. AI features require internet connectivity to external services.")
                        .font(.caption)
                }
                
                Section {
                    Button("Clear WebView Cache & Cookies") {
                        showingClearCacheAlert = true
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Storage Management")
                } footer: {
                    Text("Clears all cached data and cookies from web browsers used in the app, including price search and API key management pages.")
                        .font(.caption)
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Clear WebView Data", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearWebViewData()
                }
            } message: {
                Text("This will clear all cached data and cookies from web browsers used in the app. You may need to log in again to websites.")
            }
        }
    }
    
    private func clearWebViewData() {
        let websiteDataStore = WKWebsiteDataStore.default()
        
        // Get all website data types
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        // Clear all website data (cache, cookies, local storage, etc.)
        websiteDataStore.removeData(ofTypes: dataTypes, modifiedSince: Date(timeIntervalSince1970: 0)) {
            print("✅ Successfully cleared all WebView cache and cookies")
        }
    }
}

#Preview {
    PrivacyView(settingsService: SettingsService())
}